<?php
declare(strict_types=1);

namespace DeepgramSdkLab\Http;

interface Transport
{
    public function send(Request $request): Response;
}
