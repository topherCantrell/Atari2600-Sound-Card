# Atari2600-Sound-Card
Custom cartridge with AY38010 sound chip.

## Links

[http://f.rdw.se/AY-3-8910-datasheet.pdf](http://f.rdw.se/AY-3-8910-datasheet.pdf)

[https://www.mdawson.net/vic20chrome/cpu/mos_6500_mpu_preliminary_may_1976.pdf](https://www.mdawson.net/vic20chrome/cpu/mos_6500_mpu_preliminary_may_1976.pdf)

[https://hackaday.io/contest/18215-the-1kb-challenge](https://hackaday.io/contest/18215-the-1kb-challenge)

[https://hackaday.io/project/18536-atari2600-sound-cartridge](https://hackaday.io/project/18536-atari2600-sound-cartridge)

## FRAM Programmer
TODO insert pictures/info on the propeller-based FRAM programmer. Add the code here.

## Hardware

Before I make a custom board, I'll breadboard everything. I pulled the ROM off an Asteroids cartridge board
and soldered on break-out wires. From right to left: GND, D0-D7, A0-A12, 5V. 

![](https://github.com/topherCantrell/Atari2600-Sound-Card/blob/master/art/breakout.jpg)

This is a close-up of a Combat cartridge board without the ROM. Notice the missing A11 pin. The Combat game
is only 2K bytes.

![](https://github.com/topherCantrell/Atari2600-Sound-Card/blob/master/art/combat.jpg)


