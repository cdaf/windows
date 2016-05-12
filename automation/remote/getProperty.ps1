$PROP_FILE = $args[0]
$PROP_NAME = $args[1]

# Brute force property retrieval, comment lines are not explicitely ignored, simply omitted as they won't match the property name sought
Foreach ($ROW in get-content $PROP_FILE) {
	$test = $ROW -split '='
	if ( $test[0] -eq $PROP_NAME ) {
		return $test[1] 
	}
}
