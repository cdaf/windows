Add-Type -AssemblyName System.Net.Http
$http = New-Object -TypeName System.Net.Http.Httpclient
$message = "Hello world."
$httpMessage = "{""text"": """ + $message + """}";
$content = New-Object -TypeName System.Net.Http.StringContent($httpMessage)
$httpResult = $http.PostAsync("https://hooks.slack.com/services/your_channel_url_here", $content).Result
