<?php
$CONFIG = array (
  'objectstore' => array(
    'class' => '\\OC\\Files\\ObjectStore\\S3',
    'arguments' => array(
      'hostname'       => 's3.vzkn.eu',
      'port'           => 443,
      'use_path_style' => true,
      'bucket'         => 'nextcloud',
      'region'         => 'main',
      'autocreate'     => false,
      'key'            => getenv('S3_ACCESS_KEY'),
      'secret'         => getenv('S3_SECRET_KEY'),
      'use_ssl'        => true,
    ),
  ),
);
