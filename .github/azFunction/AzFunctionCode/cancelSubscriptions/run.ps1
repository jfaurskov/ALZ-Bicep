# Input bindings are passed in via param block.
param($QueueItem, $TriggerMetadata)
# Write out the queue message and insertion time to the information log.
Write-Host "PowerShell queue trigger function processed work item: $QueueItem"
$subscriptionId = $QueueItem.Body.subscriptionId
Write-Host "Subscription to be canceled is $subscriptionId"
Write-Host "Queue item insertion time: $($TriggerMetadata.InsertionTime)"
#MSI to look for subscripition in current tenant
# fixme some code to cancel subscription and possibly verify that it happened
$body = @{
    subscriptionId = $subscriptionId
} 
Push-OutputBinding -Name canceledSubscriptions -Value ([HttpResponseContext]@{
        Body = $body
    })

