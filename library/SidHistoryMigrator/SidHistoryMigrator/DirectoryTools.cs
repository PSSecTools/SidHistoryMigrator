using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace SidHistoryMigrator
{
    public static class DirectoryTools
    {
        public static void ImportSIDHistory(DSSession SourceSession, DSSession DestinationSession, string SourcePrincipal, string DestinationPrincipal)
        {
            int result = Native.DsAddSidHistory(
                DestinationSession.GetSessionPointer(),
                0,
                SourceSession.Domain,
                SourcePrincipal,
                SourceSession.Server,
                SourceSession.GetCredentialPointer(),
                DestinationSession.Domain,
                DestinationPrincipal
            );
            if (result != 0)
                throw new Win32Exception(result);
        }
    }
}
