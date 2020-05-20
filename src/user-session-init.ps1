Import-Module awspowershell.netcore

function InitUserSession {

    # Copy AWS CLI credentials to AWS SDK credentials store
    Set-AWSCredential -AccessKey (aws configure get aws_access_key_id --profile default) -SecretKey (aws configure get aws_secret_access_key --profile default) -StoreAs default
    
    # Diagnostic output
    Write-Information "Retrieving current AWS SDK credentials `"default`" profile:"
    Get-AWSCredential -ProfileName default
}

InitUserSession `
    -workDirectory $workDirectory `
    *> C:\aws-workshop-user-session-init.log