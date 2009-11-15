<?php

$layout = file_get_contents('layout.html');

$_SERVER{'QUERY_STRING'} = preg_replace('/\.\.\//', '', $_SERVER{'QUERY_STRING'});

if(file_exists("pages/{$_SERVER{'QUERY_STRING'}}.html-inc"))
{
	echo strtr($layout, array('<div id="main" />' => '<div id="main">' . file_get_contents("pages/{$_SERVER{'QUERY_STRING'}}.html-inc") . '</div>'));
}
else
{
	echo strtr($layout, array('<div id="main" />' => '<div id="main">' . file_get_contents("pages/index.html-inc") . '</div>'));
}

?>