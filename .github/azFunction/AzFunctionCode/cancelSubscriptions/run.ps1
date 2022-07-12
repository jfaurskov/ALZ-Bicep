# Input bindings are passed in via param block.
param($QueueItem, $TriggerMetadata)
# Write out the queue message and insertion time to the information log.
Write-Host "PowerShell queue trigger function processed work item: $QueueItem"
$subscriptionId = $QueueItem.Body.subscriptionId
$subscriptionName = $QueueItem.Body.subscriptionName
Write-Host "Subscription to be canceled is $subscriptionName with id: $subscriptionId"

#MSI to look for subscripition in current tenant
# fixme some code to cancel subscription and possibly verify that it happened
$body = @{
    subscriptionName = $subscriptionName
    subscriptionId = $subscriptionId
} 
Push-OutputBinding -Name canceledSubscriptions -Value ([HttpResponseContext]@{
        Body = $body
    })
Write-Host "Queue item insertion time: $($TriggerMetadata.InsertionTime)"

