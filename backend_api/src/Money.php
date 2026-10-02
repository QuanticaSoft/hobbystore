<?php

declare(strict_types=1);

final class Money
{
    /** Mismo formato que la app (formatBob): "Bs 3.480" o "Bs 1.250,50". */
    public static function bob(float $amount): string
    {
        $cents = (int) round($amount * 100);
        $whole = number_format(intdiv($cents, 100), 0, ',', '.');
        $fraction = $cents % 100;
        return $fraction === 0 ? "Bs $whole" : sprintf('Bs %s,%02d', $whole, $fraction);
    }
}
