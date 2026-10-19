using System;
using System.Diagnostics;
using System.IO;
using System.Net.NetworkInformation;
using System.ServiceProcess;
using System.Threading;

namespace ZapretVpnSync
{
    public class VpnSyncService : ServiceBase
    {
        public const string ServiceNameString = "ZapretVpnSync";
        public const string ServiceDisplayName = "Zapret INCY VPN Sync";
        private const string ZapretServiceName = "zapret";

        private Thread _workerThread;
        private volatile bool _running = false;
        private bool? _lastVpnState = null;
        private readonly object _syncLock = new object();

        public VpnSyncService()
        {
            this.ServiceName = ServiceNameString;
            this.CanStop = true;
            this.CanPauseAndContinue = false;
            this.AutoLog = true;
        }

        protected override void OnStart(string[] args)
        {
            _running = true;
            _workerThread = new Thread(WorkerLoop)
            {
                IsBackground = true,
                Name = "ZapretVpnSyncWorker"
            };
            _workerThread.Start();
            Log("ZapretVpnSync service started successfully.");
        }

        protected override void OnStop()
        {
            _running = false;
            if (_workerThread != null && _workerThread.IsAlive)
            {
                _workerThread.Join(3000);
            }
            Log("ZapretVpnSync service stopped.");
        }

        public void RunInteractive()
        {
            Console.WriteLine("==================================================");
            Console.WriteLine("  Zapret & INCY VPN Sync Monitor (Interactive)");
            Console.WriteLine("  Press Ctrl+C to stop.");
            Console.WriteLine("==================================================");
            OnStart(new string[0]);
            while (_running)
            {
                Thread.Sleep(1000);
            }
        }

        private void WorkerLoop()
        {
            // Subscribe to system network address changes (0% CPU event-driven)
            try
            {
                NetworkChange.NetworkAddressChanged += OnNetworkChanged;
                NetworkChange.NetworkAvailabilityChanged += OnNetworkAvailabilityChanged;
            }
            catch (Exception ex)
            {
                Log("Warning: Could not subscribe to NetworkChange events: " + ex.Message);
            }

            // Perform initial state check
            CheckAndSync();

            // Fallback polling loop (2 seconds) with minimal resource usage
            while (_running)
            {
                Thread.Sleep(2000);
                CheckAndSync();
            }

            try
            {
                NetworkChange.NetworkAddressChanged -= OnNetworkChanged;
                NetworkChange.NetworkAvailabilityChanged -= OnNetworkAvailabilityChanged;
            }
            catch { }
        }

        private void OnNetworkChanged(object sender, EventArgs e)
        {
            CheckAndSync();
        }

        private void OnNetworkAvailabilityChanged(object sender, NetworkAvailabilityEventArgs e)
        {
            CheckAndSync();
        }

        private bool IsIncyVpnActive()
        {
            try
            {
                var interfaces = NetworkInterface.GetAllNetworkInterfaces();
                foreach (var iface in interfaces)
                {
                    if (iface.OperationalStatus != OperationalStatus.Up)
                        continue;

                    string desc = iface.Description ?? "";
                    string name = iface.Name ?? "";

                    // Detect Wintun / wwan99 / Incy TUN adapter
                    bool isVpnTunnel = desc.IndexOf("Wintun", StringComparison.OrdinalIgnoreCase) >= 0 ||
                                       desc.IndexOf("WireGuard", StringComparison.OrdinalIgnoreCase) >= 0 ||
                                       name.IndexOf("wwan99", StringComparison.OrdinalIgnoreCase) >= 0 ||
                                       name.IndexOf("incy", StringComparison.OrdinalIgnoreCase) >= 0;

                    if (isVpnTunnel)
                    {
                        var ipProps = iface.GetIPProperties();
                        if (ipProps != null && ipProps.UnicastAddresses != null && ipProps.UnicastAddresses.Count > 0)
                        {
                            return true;
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Log("Error during network scan: " + ex.Message);
            }
            return false;
        }

        private void CheckAndSync()
        {
            lock (_syncLock)
            {
                bool vpnActive = IsIncyVpnActive();

                if (_lastVpnState.HasValue && _lastVpnState.Value == vpnActive)
                {
                    return; // No change in VPN state
                }

                _lastVpnState = vpnActive;

                if (vpnActive)
                {
                    Log("[STATUS] INCY VPN connected. Stopping '" + ZapretServiceName + "' service...");
                    SetServiceState(ZapretServiceName, false);
                }
                else
                {
                    Log("[STATUS] INCY VPN disconnected. Starting '" + ZapretServiceName + "' service...");
                    SetServiceState(ZapretServiceName, true);
                }
            }
        }

        private void SetServiceState(string serviceName, bool start)
        {
            try
            {
                using (var sc = new ServiceController(serviceName))
                {
                    // Refresh service status
                    sc.Refresh();

                    if (start)
                    {
                        if (sc.Status == ServiceControllerStatus.Stopped || sc.Status == ServiceControllerStatus.StopPending)
                        {
                            if (sc.Status == ServiceControllerStatus.StopPending)
                            {
                                sc.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(5));
                            }
                            sc.Start();
                            sc.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(10));
                            Log("[SUCCESS] Service '" + serviceName + "' STARTED.");
                        }
                        else if (sc.Status == ServiceControllerStatus.Running)
                        {
                            Log("[INFO] Service '" + serviceName + "' is already running.");
                        }
                    }
                    else
                    {
                        if (sc.Status == ServiceControllerStatus.Running || sc.Status == ServiceControllerStatus.StartPending)
                        {
                            if (sc.Status == ServiceControllerStatus.StartPending)
                            {
                                sc.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(5));
                            }
                            sc.Stop();
                            sc.WaitForStatus(ServiceControllerStatus.Stopped, TimeSpan.FromSeconds(10));
                            Log("[SUCCESS] Service '" + serviceName + "' STOPPED.");
                        }
                        else if (sc.Status == ServiceControllerStatus.Stopped)
                        {
                            Log("[INFO] Service '" + serviceName + "' is already stopped.");
                        }
                    }
                }
            }
            catch (InvalidOperationException)
            {
                Log("[WARN] Service '" + serviceName + "' was not found on this system.");
            }
            catch (Exception ex)
            {
                Log("[ERROR] Failed to modify service '" + serviceName + "': " + ex.Message);
            }
        }

        private static void Log(string message)
        {
            string line = string.Format("[{0:yyyy-MM-dd HH:mm:ss}] {1}", DateTime.Now, message);
            Console.WriteLine(line);
            try
            {
                string dir = AppDomain.CurrentDomain.BaseDirectory;
                string logPath = Path.Combine(dir, "sync.log");
                File.AppendAllText(logPath, line + Environment.NewLine);
            }
            catch { }
        }

        public static void Main(string[] args)
        {
            bool interactive = Environment.UserInteractive;
            if (args != null && args.Length > 0)
            {
                foreach (var arg in args)
                {
                    if (arg.Equals("--console", StringComparison.OrdinalIgnoreCase) || arg.Equals("-c", StringComparison.OrdinalIgnoreCase))
                    {
                        interactive = true;
                    }
                }
            }

            var service = new VpnSyncService();

            if (interactive)
            {
                service.RunInteractive();
            }
            else
            {
                ServiceBase.Run(service);
            }
        }
    }
}
