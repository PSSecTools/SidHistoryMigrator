using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace SidHistoryMigrator
{
    public class DSSession : IDisposable
    {
        public PSCredential Credential;
        public string Domain;
        public string Server;

        private IntPtr _Session;
        private IntPtr _Credential;

        public void Authenticate()
        {
            if (null == Credential)
                throw new ArgumentException("No Credentials provided to authenticate with!");

            if (IntPtr.Zero != _Session)
                Native.DsUnBind(_Session);
            if (IntPtr.Zero != _Credential)
                Native.DsFreePasswordCredentials(_Credential);

            string user = Credential.UserName;
            string domain = Environment.GetEnvironmentVariable("UserDNSDomain");
            if (Regex.IsMatch(user, "^\\w+\\\\\\w+$"))
            {
                string[] parts = user.Split('\\');
                domain = parts[0];
                user = parts[1];
            }

            int result = Native.DsMakePasswordCredentials(user, domain, Credential.GetNetworkCredential().Password, out _Credential);
            if (result != 0)
                throw new Win32Exception(result);
        }

        public void Connect(string DnsDomainName, string DomainControllerName)
        {
            if (_Session != IntPtr.Zero)
                Native.DsUnBind(_Session);

            int result = Native.DsBindWithCred(DomainControllerName, DnsDomainName, _Credential, out _Session);
            if (result != 0)
                throw new Win32Exception(result);

            Domain = DnsDomainName;
            Server = DomainControllerName;
        }

        public IntPtr GetSessionPointer()
        {
            return _Session;
        }

        public IntPtr GetCredentialPointer()
        {
            return _Credential;
        }

        public void Dispose()
        {
            if (IntPtr.Zero != _Session)
                Native.DsUnBind(_Session);
            if (IntPtr.Zero != _Credential)
                Native.DsFreePasswordCredentials(_Credential);
        }
    }
}
