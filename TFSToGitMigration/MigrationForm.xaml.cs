using System;
using System.Threading.Tasks;
using System.Windows;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using Microsoft.PowerShell;
using System.Windows.Media;
using System.Windows.Navigation;

namespace TFSToGitMigrationTool
{
    public partial class MigrationForm : Window
    {
        public MigrationForm()
        {
            InitializeComponent();
            txt_Output.TextChanged += TxtOutput_TextChangedEventHandler;
        }

        public void OpenHyperlinkInDefaultBrowser(object sender, RequestNavigateEventArgs e)
        {
            var sInfo = new System.Diagnostics.ProcessStartInfo(e.Uri.ToString())
            {
                UseShellExecute = true,
            };
            System.Diagnostics.Process.Start(sInfo);
        }

        private async void btn_Migrate_Click(object sender, RoutedEventArgs e)
        {
            txt_Output.Foreground = new SolidColorBrush(Colors.White);

            if (FormIsValid())
            {
                try
                {
                    await PerformMigration();
                }
                catch (RuntimeException runtimeException)
                {
                    txt_Output.Foreground = new SolidColorBrush(Colors.Red);
                    txt_Output.AppendText("There was an error performing the migration" + Environment.NewLine);
                    txt_Output.AppendText(runtimeException.Message + Environment.NewLine);
                    txt_Output.AppendText(runtimeException.ErrorRecord.ScriptStackTrace + Environment.NewLine);
                    btn_Migrate.IsEnabled = true;
                    return;
                }
                catch (Exception exception)
                {
                    txt_Output.Foreground = new SolidColorBrush(Colors.Red);
                    txt_Output.AppendText("There was an error performing the migration" + Environment.NewLine);
                    txt_Output.AppendText(exception.Message + Environment.NewLine);
                    btn_Migrate.IsEnabled = true;
                    return;
                }

                txt_Output.Foreground = new SolidColorBrush(Colors.Green);
            }
        }

        private bool FormIsValid()
        {
            ClearOutput();
            var isVaild = true;

            if (string.IsNullOrWhiteSpace(txtBox_TFSWorkspacePath.Text))
            {
                txt_Output.Text += "Local TFS Workspace Path is required" + Environment.NewLine;
                isVaild = false;
            }


            if (string.IsNullOrWhiteSpace(txtBox_MigrationFolderPath.Text))
            {
                txt_Output.Text += "Migration Folder Path is required" + Environment.NewLine;
                isVaild = false;
            }

            if (string.IsNullOrWhiteSpace(txtBox_TFSRepoPath.Text))
            {
                txt_Output.Text += "TFS Repo Path is required" + Environment.NewLine;
                isVaild = false;
            }

            if (string.IsNullOrWhiteSpace(txtBox_GitRepoName.Text))
            {
                txt_Output.Text += "Git Repo Name is required" + Environment.NewLine;
                isVaild = false;
            }

            return isVaild;
        }

        private async Task PerformMigration()
        {
            ClearOutput();
            btn_Migrate.IsEnabled = false;

            // Create a default initial session state and set the execution policy to Unrestricted to allow migration script to run
            InitialSessionState initialSessionState = InitialSessionState.CreateDefault();
            initialSessionState.ExecutionPolicy = ExecutionPolicy.Bypass;

            using Runspace runspace = RunspaceFactory.CreateRunspace(initialSessionState);
            runspace.Open();

            using PowerShell ps = PowerShell.Create(runspace);

            //Add a handeler to add the Write-Host output to txt_Output
            ps.Streams.Information.DataAdded += InformationEventHandler;

            ps.AddCommand(AppDomain.CurrentDomain.BaseDirectory + "\\Migrate.ps1");
            ps.AddParameter("AzureDevOpsBaseUrl", "https://dev.azure.com/swansea-university");
            ps.AddParameter("AzureDevOpsBaseGitUrl", "https://swansea-university@dev.azure.com/swansea-university/IT/_git/");
            ps.AddParameter("GitIgnoreUrl", "https://raw.githubusercontent.com/github/gitignore/main/VisualStudio.gitignore");
            ps.AddParameter("LocalTfsWorkspacePath", txtBox_TFSWorkspacePath.Text.Trim());
            ps.AddParameter("MigrationFolder", txtBox_MigrationFolderPath.Text.Trim());
            ps.AddParameter("TFSRepoPath", txtBox_TFSRepoPath.Text.Trim());
            ps.AddParameter("GitRepoName", txtBox_GitRepoName.Text.Trim());

            await ps.InvokeAsync();

            Dispatcher.Invoke(() => { btn_Migrate.IsEnabled = true; });
        }

        private void TxtOutput_TextChangedEventHandler(object sender, EventArgs e)
        {
            txt_Output.ScrollToEnd();
        }

        private void InformationEventHandler(object sender, DataAddedEventArgs e)
        {
            //Need to do this on a Dispatcher as this isnt run on the main thread.
            Dispatcher.Invoke(() =>
            {
                var data = (sender as PSDataCollection<InformationRecord>)[e.Index];
                txt_Output.AppendText(data.MessageData.ToString() + Environment.NewLine);
            });
        }

        private void ClearOutput()
        {
            txt_Output.Text = string.Empty;
        }
    }
}
