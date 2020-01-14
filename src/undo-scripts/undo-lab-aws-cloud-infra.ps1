param(
    [string[]] $cicdPipelineCfnStackNames = @(
        "Unicorn-Store-CI-CD-PipelineStack",
        "UnicornSuperstoreStack"
    ),
    [string] $ecrRepoName = "unicorn-store-app"
)

Import-Module awspowershell.netcore

# Include scripts with utility functions
. ../aws.ps1

ConfigureCurrentAwsRegion
DeleteCfnStacks($cicdPipelineCfnStackNames)
Remove-ECRRepository -RepositoryName $ecrRepoName -Force