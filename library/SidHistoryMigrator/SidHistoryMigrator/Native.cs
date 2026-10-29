using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;

namespace SidHistoryMigrator
{
    public static class Native
    {
        [DllImport("Ntdsapi.dll", SetLastError = true)]
        public static extern int DsBind(
            string DomainControllerName,
            string DnsDomainName,
            out IntPtr Connection
        );

        [DllImport("Ntdsapi.dll", SetLastError = true)]
        public static extern int DsUnBind(
            IntPtr Connection
        );

        [DllImport("Ntdsapi.dll", SetLastError = true)]
        public static extern int DsBindWithCred(
            string DomainControllerName,
            string DnsDomainName,
            IntPtr AuthHandle,
            out IntPtr Connection
        );

        [DllImport("Ntdsapi.dll", SetLastError = true)]
        public static extern int DsMakePasswordCredentials(
            string User,
            string Domain,
            string Password,
            out IntPtr AuthHandle
        );

        [DllImport("Ntdsapi.dll", SetLastError = true)]
        public static extern int DsFreePasswordCredentials(
            IntPtr AuthHandle
        );

        [DllImport("Ntdsapi.dll", SetLastError = true)]
        public static extern int DsAddSidHistory(
            IntPtr SessionHandle,
            uint Flags,
            string SrcDomain,
            string SrcPrincipal,
            string SrcDomainController,
            IntPtr SrcCredentialHandle,
            string DstDomain,
            string DstPrincipal
        );
    }
}
