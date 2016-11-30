.cpu 6502

.include "stella.asm"

;  RAM usage

.TMP0             =     128
.TMP1             =     129
.TMP2             =     130
.PLAYR0Y          =     131
.SCANCNT          =     135
.MODE             =     136
.WALL_INC         =     137
.WALLCNT          =     138
.WALLDELY         =     139
.WALLDELYR        =     140
.ENTROPYA         =     141
.ENTROPYB         =     142
.ENTROPYC         =     143
.DEBOUNCE         =     144
.WALLDRELA        =     145
.WALLDRELB        =     146
.WALLDRELC        =     147
.WALLSTART        =     148
.WALLHEI          =     149
.GAPBITS          =     150
.SCORE_PF1        =     151
.SCORE_PF2        =     157

F000:
main:
         SEI                   ; Turn off interrupts
         CLD                   ; Clear the "decimal" flag

; http://atariage.com/forums/topic/27405-session-12-initialisation
; Nice, tight code to clear memory and registers at startup
         LDX   #0              ; 0 to ...
         TXS                   ; ... SP
         PHA                   ; SP is now FF (the end of memory)
         TXA                   ; 0 to A (for clearing memory)
clear:   PHA                   ; Store 0
         DEX                   ; All 256 of memory+registers cleared?
         BNE   clear           ; No ... do all. SP ends at FF again

         JSR  INIT             ; Initialize game environment
         JSR  INIT_SELMODE     ; Start out in SELECT-MODE (fall into main loop)

; Start here at the end of every screen frame
;
VIDEO_KERNEL:

	     LDA   #2              ; D1 bit ON
	     STA   WSYNC           ; Wait for the end of the current line
	     STA   VBLANK          ; Turn the electron beam off
	     STA   WSYNC           ; Wait ...
	     STA   WSYNC           ; ... three ...
	     STA   WSYNC           ; ... scanlines
	     STA   VSYNC           ; Trigger the vertical sync signal
	     STA   WSYNC           ; Hold the vsync signal for ...
	     STA   WSYNC           ; ... three ...
	     STA   WSYNC           ; ... scanlines
	     STA   HMOVE           ; Tell hardware to move all game objects
	     LDA   #0              ; Release ...
	     STA   VSYNC           ; ... the vertical sync signal
	     LDA   #43             ; Set timer to 43*64 = 2752 machine ...
	     STA   TIM64T          ; ... cycles 2752/(228/3) = 36 scanlines

         ;  ***** LENGTHY GAME LOGIC PROCESSING BEGINS HERE *****

         ;  Do one of 3 routines while the beam travels back to the top
         ;  0 = Game Over processing
         ;  1 = Playing-Game processing
         ;  2 = Selecting-Game processing

         INC   ENTROPYA        ; Counting video frames as part of the random number

         LDA   MODE            ; What are we doing between frames?
         CMP   #0              ; Mode is ...
         BEQ   DoGameOverMode  ; ... "game over"
         CMP   #1              ; Mode is ...
         BEQ   DoPlayMode      ; ... "game play"
         JSR   SELMODE         ; Mode is "select game"
         JMP   DrawFrame       ; Continue to the visible screen area

DoPlayMode:
         JSR   PLAYMODE        ; Playing-game processing
         JMP   DrawFrame

DoGameOverMode:
         JSR   GOMODE          ; Game-over processing

DrawFrame:
         ;  ***** LENGTHY GAME LOGIC PROCESSING ENDS HERE *****

         LDA   INTIM           ; Wait for ...
	     CMP   #0              ; ... the visible area ...
	     BNE   DrawFrame       ; ... of the screen

	     STA   WSYNC           ; 37th scanline
	     LDA   #0              ; Turn the ...
	     STA   VBLANK          ; ... electron beam back on

	     LDA   #0              ; Zero out ...
	     STA   SCANCNT         ; ... scanline count ...
	     STA   TMP0            ; ... and all ...
	     STA   TMP1            ; ... returns ...
	     STA   TMP2            ; ... expected ...
	     TAX                   ; ... to come from ...
	     TAY                   ; ... BUILDROW

	     STA   CXCLR           ; Clear collision detection

DrawVisibleRows:

         ;  BEGIN VISIBLE PART OF FRAME

         LDA   TMP0            ; Get A ready (PF0 value)
	     STA   WSYNC           ; Wait for very start of row
	     STX   GRP0            ; Player 0 -- in X
	     ;STY   GRP1            ; Player 1 -- in Y
	     STA   PF0             ; PF0      -- in TMP0 (already in A)
	     LDA   TMP1            ; PF1      -- in TMP1
	     STA   PF1             ; ...
	     LDA   TMP2            ; PP2      -- in TMP2
	     STA   PF2             ; ...

	     JSR   BUILDROW        ; This MUST take through to the next line

	     INC   SCANCNT         ; Next scan line
	     LDA   SCANCNT         ; Do 109*2 = 218 lines
	     CMP   #109            ; All done?
	     BNE   DrawVisibleRows ; No ... get all the visible rows

	     ;  END VISIBLE PART OF FRAME

	     LDA   #0              ; Turn off electron beam
	     STA   WSYNC           ; Next scanline
	     STA   PF0             ; Play field 0 off
	     STA   GRP0            ; Player 0 off
	     ;STA   GRP1            ; Player 1 off
	     STA   PF1             ; Play field 1 off
	     STA   PF2             ; Play field 2 off
	     STA   WSYNC           ; Next scanline

	     JMP   VIDEO_KERNEL    ; Back to top of main loop

BUILDROW:

	     LDA   SCANCNT         ; Where are we on the screen?

	     CMP   #6              ; If we are in the ...
	     BCC   ShowScore       ; ... score area

	     AND   #7              ; Lower 3 bits as an index again
	     TAY                   ; Using Y to lookup graphics
	     LDA   GR_PLAYER,Y     ; Get the graphics (if enabled on this row)
	     TAX                   ; Hold it (for return as player 0)
	     TAY                   ; Hold it (for return as player 1)
	     LDA   SCANCNT         ; Scanline count again
	     LSR   A               ; This time ...
	     LSR   A               ; ... we divide ...
	     LSR   A               ; ... by eight (8 rows in picture)

	     CMP   PLAYR0Y         ; Scanline group of the P0 object?
	     BEQ   ShowP0          ; Yes ... keep the picture
	     LDX   #0              ; Not time for Player 0 ... no graphics
ShowP0:
	     LDA   WALLSTART       ; Calculate ...
	     CLC                   ; ... the bottom ...
	     ADC   WALLHEI         ; ... of ...
	     STA   TMP0            ; ... the wall

	     LDA   SCANCNT         ; Scanline count

	     CMP   WALLSTART       ; Past upper part of wall?
	     BCC   NoWall          ; No ... skip it
	     CMP   TMP0            ; Past lower part of wall
	     BCS   NoWall          ; Yes ... skip it

	     ;  The wall is on this row
	     LDA   WALLDRELA       ; Draw wall ...
	     STA   TMP0            ; ... by transfering ...
	     LDA   WALLDRELB       ; ... playfield ...
	     STA   TMP1            ; ... patterns ...
	     LDA   WALLDRELC       ; ... to ...
	     STA   TMP2            ; ... return area
	     RTS                   ; Done

NoWall:
	     ;  The wall is NOT on this row
	     LDA   #0              ; No walls on this row
	     STA   TMP0            ; ... clear ...
	     STA   TMP1            ; ... out ...
	     STA   TMP2            ; ... the playfield
	     RTS                   ; Done

ShowScore:
	     AND   #7              ; Only need the lower 3 bits
	     TAY                   ; Soon to be an index into a list

	     ;  At this point, the beam is past the loading of the
	     ;  playfield for the left half. We want to make sure
	     ;  that the right half of the playfield is off, so do that
	     ;  now.

	     LDX   #0              ; Blank bit pattern
	     STX   TMP0            ; This will always be blank
	     STX   PF1             ; Turn off playfield ...
	     STX   PF2             ; ... for right half of the screen

	     TAX                   ; Another index
	     LDA   SCORE_PF1,Y     ; Lookup the PF1 graphics for this row
	     STA   TMP1            ; Return it to the caller
	     TAY                   ; We'll need this value again in a second
	     LDA   SCORE_PF2,X     ; Lookup the PF2 graphics for this row
	     STA   TMP2            ; Return it to the caller

	     STA   WSYNC           ; Now on the next row

	     STY   PF1             ; Repeat the left-side playfield ...
	     STA   PF2             ; ... onto the new row

	     LDA   SCORE_PF2,X     ; Kill some time waiting for the ...
	     LDA   SCORE_PF2,X     ; ... beam to pass the left half ...
	     LDA   SCORE_PF2,X     ; ... of the playfield again
	     LDA   SCORE_PF2,X     ; ...
	     LDA   SCORE_PF2,X     ; ...
	     LDA   SCORE_PF2,X     ; ...

	     LDX   #0              ; Return 0 (off) for player 0 ...
	     LDY   #0              ; ... and player 1

	     ;  The beam is past the left half of the field again.
	     ;  Turn off the playfield.

	     STX   PF1             ; 0 to PF1 ...
	     STX   PF2             ; ... and PF2
	     RTS                   ;  Done


    ;  ============= END OF VIDEO KERNEL ===================

INIT:
         ;  This function is called ONCE at power-up/reset to initialize various
         ;  game settings and variables.

         LDA      #64              ; Wall is ...
         STA      COLUPF           ; ... redish
         LDA      #126             ; P0 is ...
         STA      COLUP0           ; ... white
         LDA      #0               ; P1 ...
         STA      COLUP1           ; ... black

         LDA      #5               ; Right half of playfield is reflection of left ...
         STA      CTRLPF           ; ... and playfield is on top of players

         LDX      #4               ; Player 0 position count
         LDY      #3               ; Player 1 position count
    STA      WSYNC            ; Get a fresh scanline

TimeP0Pos:
    DEX                       ; Kill time while the beam moves ...
    CPX      #0               ; ... to desired ...
    BNE      TimeP0Pos        ; ... position
    STA      RESP0            ; Mark player 0's X position

    LDA      #10              ; Wall is ...
    STA      WALLHEI          ; ... 10 double-scanlines high

    LDA      #0               ; Set score to ...
    STA      WALLCNT          ; ... 0
    JSR      MAKE_SCORE       ; Blank the score digits
    LDA      #0               ; Blank bits ...
    STA      SCORE_PF2+5      ; ... on the end of each ...
    STA      SCORE_PF1+5      ; ... digit pattern

    JSR      ADJUST_DIF       ; Initialize the wall parameters
    JSR      NEW_GAPS         ; Build the wall's initial gap

    LDA      #112             ; Set wall position off bottom ...
    STA      WALLSTART        ; ... to force a restart on first move

    LDA      #0               ; Zero out ...
    STA      HMP0             ; ... player 0 motion ...
    STA      HMP1             ; ... and player 1 motion

    RTS                       ; Done

INIT_PLAYMODE:

    ;  This function initializes the game play mode

    LDA      #192             ; Background is ...
    STA      COLUBK           ; ... greenish
    LDA      #1               ; Game mode is ...
    STA      MODE             ; ... SELECT
    LDA      #255             ; Restart wall score to ...
    STA      WALLCNT          ; ... 0 on first move
    LDA      #112             ; Force wall to start ...
    STA      WALLSTART        ; ... over on first move
    JSR      INIT_MUSIC       ; Initialize the music
    RTS                       ; Done


PLAYMODE:

    ;  This function is called once per frame to process the main game play.


    JSR      SEL_RESET_CHK    ; Check to see if Reset/Select has changed

    CMP      #0               ; Is select pressed?
    BEQ      NoSelect         ; No ... skip
    STX      DEBOUNCE         ; Restore the old value ...
    JSR      INIT_SELMODE     ; ... and let select-mode process the toggle
    RTS                       ; Done

NoSelect:
    JSR      PROCESS_MUSIC    ; Process any playing music
    JSR      MOVE_WALLS       ; Move the walls

    CMP      #1               ; Wall on first row?
    BNE      NoFirst          ; No ... move on
    INC      WALLCNT          ; Bump the score
    JSR      ADJUST_DIF       ; Change the wall parameters based on score
    LDA      WALLCNT          ; Change the ...
    JSR      MAKE_SCORE       ; ... score pattern
    JSR      NEW_GAPS         ; Calculate the new gap position

NoFirst:
     LDA      CXP0FB           ; Player 0 collision with playfield
     AND      #128             ; Did player hit ...
     CMP      #0               ; ... wall?
     BEQ      NoHit            ; No ... move on
     JSR      INIT_GOMODE      ; Go to Game-Over mode
     RTS                       ; Done

NoHit:
     LDA      SWCHA            ; Joystick
     AND      #128             ; Player 0 ...
     CMP      #0               ; ... moving left?
     BEQ      MoveP0Left       ; Yes ... move left
     LDA      SWCHA            ; Joystick
     AND      #64              ; Player 0 ...
     CMP      #0               ; ... moving right?
     BEQ      MoveP0Right      ; Yes ... move right
     LDA      #0               ; Not moving value
     JMP      SetMoveP0        ; Don't move the player
MoveP0Right:
     LDA      #16              ; +1
     JMP      SetMoveP0        ; Set HMP0
MoveP0Left:
     LDA      #240             ; -1
SetMoveP0:
     STA      HMP0             ; New movement value P0

     RTS                       ; Done

INIT_SELMODE:
     ;
     ;  This function initializes the games SELECT-MODE
     ;
     LDA      #200             ; Background ...
     STA      COLUBK           ; ... greenish bright
     LDA      #2               ; Now in ...
     STA      MODE             ; SELECT game mode
     RTS                       ; Done

SELMODE:
     ;
     ;  This function is called once per frame to process the SELECT-MODE.
     ;  The wall moves here, but doesn't change or collide with players.
     ;  This function selects between 1 and 2 player game.
     ;
     JSR      MOVE_WALLS       ; Move the walls
     JSR      SEL_RESET_CHK    ; Check the reset/select switches
     CMP      #1               ; RESET button?
     BEQ      SelStartGame     ; Yes ... start game
     CMP      #3               ; RESET and SELECT?
     BEQ      SelStartGame     ; Yes ... start game
     JMP      SelExp           ; Move to expertise

SelStartGame:
     JSR      INIT_PLAYMODE    ; Reset toggled ... start game
SelExp:
     JSR      EXPERTISE        ; Adjust both players for pro settings
     RTS                       ; Done

INIT_GOMODE:

     ;  This function initializes the GAME-OVER game mode.

     STA      HMCLR            ; Stop both players from moving
     LDA      #0               ; Going to ...
     STA      MODE             ; ... game-over mode
     JSR      INIT_GO_FX       ; Initialize sound effects
     RTS                       ; Done

GOMODE:

     ; This function is called every frame to process the game
     ; over sequence. When the sound effect has finished, the
     ; game switches to select mode.

     JSR      PROCESS_GO_FX    ; Process the sound effects
     CMP      #0               ; Effects still running?
     BEQ      GoKeepGoing      ; Yes ... let them run
     JSR      INIT_SELMODE     ; When effect is over, go to select mode
GoKeepGoing:
     RTS                       ; Done

MOVE_WALLS:

     ;  This function moves the wall down the screen and back to position 0
     ;  when it reaches (or passes) 112.

     DEC      WALLDELY         ; Wall motion timer
     LDA      WALLDELY         ; Time to ...
     CMP      #0               ; ... move the wall?
     BNE      WallDone         ; No ... leave it alone
     LDA      WALLDELYR        ; Reset the ...
     STA      WALLDELY         ; ... delay count
     LDA      WALLSTART        ; Current wall position
     CLC                       ; Increment ...
     ADC      WALL_INC         ; ... wall position
     CMP      #112             ; At the bottom?
     BCC      WallOK           ; No ... leave it alone
     LDA      #0               ; Else restart ...
     STA      WALLSTART        ; ... wall at top of screen
     LDA      #1               ; Return flag that wall DID restart
     RTS                       ; Done
WallOK:
     STA      WALLSTART        ; Store new wall position
WallDone:
     LDA      #0               ; Return flag that wall did NOT restart
     RTS                       ; Done

NEW_GAPS:                                  ;  --SubroutineContextBegins--
     ;  This function builds the PF0, PF1, and PF2 graphics for a wall
     ;  with the gap pattern (GAPBITS) placed at random in the 20 bit
     ;  area.

     LDA      #255             ; Start with ...
     STA      WALLDRELA        ; ... solid wall in PF0 ...
     STA      WALLDRELB        ; ... and PF1
     LDA      GAPBITS          ; Store the gap pattern ...
     STA      WALLDRELC        ; ... in PF2

                 LDA      ENTROPYA         ; OLine=552  Get ...
                 ADC      ENTROPYB         ; OLine=553  ... a randomish ...
                 ADC      ENTROPYC         ; OLine=554  ... number ...
                 STA      ENTROPYC         ; OLine=555

                AND      #15              ; 0 to 15
     CMP      #12              ; Too far to the right?
     BEQ      GapOK            ; No ... 12 is OK
     BCC      GapOK            ; No ... less than 12 is OK
     SBC      #9               ; Back up 9

GapOK:
     CMP      #0               ; Gap already at far left?
     BEQ      GapDone          ; Yes ... done
     SEC                       ; Roll gap ...
     ROR      WALLDRELC        ; ... left ...
     ROL      WALLDRELB        ; ... desired ...
     ROR      WALLDRELA        ; ... times ...
     SEC                       ; All rolls ...
     SBC      #1               ; ... done?
     JMP      GapOK            ; No ... do them all
GapDone:
     RTS                       ; New wall pattern is ready

MAKE_SCORE:

     ;  This function builds the PF1 and PF2 graphics rows for
     ;  the byte value passed in A. The current implementation is
     ;  two-digits only ... PF2 is blank.

     LDX      #0               ; 100's digit
     LDY      #0               ; 10's digit

Count100s:
     CMP      #100             ; Need another 100s digit?
     BCC      Count10s         ; No ... move on to 10s
     INX                       ; Count ...
     SEC                       ; ... value
     SBC      #100             ; Take off this 100
     JMP      Count100s        ; Keep counting
Count10s:
     CMP      #10              ; Need another 10s digit?
     BCC      CountDone        ; No ... got all the tens
     INY                       ; Count ...
     SEC                       ; ... value
     SBC      #10              ; Take off this 10
     JMP      Count10s         ; Keep counting

CountDone:
     ASL      A                ; One's digit ...
     ASL      A                ; ... *8 ....
     ASL      A                ; ... to find picture
     TAX                       ; One's digit picture to X
     TYA                       ; Now the 10's digit
     ASL      A                ; Multiply ...
     ASL      A                ; ... by 8 ...
     ASL      A                ; ... to find picture
     TAY                       ; 10's picture in Y

     LDA      DIGITS,Y         ; Get the 10's digit
     AND      #0xF0            ; Upper nibble
     STA      SCORE_PF1        ; Store left side
     LDA      DIGITS,X         ; Get the 1's digit
     AND      #0x0F            ; Lower nibble
     ORA      SCORE_PF1        ; Put left and right half together
     STA      SCORE_PF1        ; And store image

     ; We have plenty of code space. Time and registers are at a premium.
     ; So copy/past the code for each row

     LDA      DIGITS+1,Y       ; Repeat for 2nd line of picture ...
     AND      #0xF0            ; ...
     STA      SCORE_PF1+1      ; ...
     LDA      DIGITS+1,X       ; ...
     AND      #15              ; ...
     ORA      SCORE_PF1+1      ; ...
     STA      SCORE_PF1+1      ; ...

     LDA      DIGITS+2,Y       ; Repeat for 3nd line of picture
     AND      #0xF0            ; ...
     STA      SCORE_PF1+2      ; ...
     LDA      DIGITS+2,X       ; ...
     AND      #0x0F            ; ...
     ORA      SCORE_PF1+2      ; ...
     STA      SCORE_PF1+2      ; ...

     LDA      DIGITS+3,Y       ; Repeat for 4th line of picture
     AND      #0xF0            ; ...
     STA      SCORE_PF1+3      ; ...
     LDA      DIGITS+3,X       ; ...
     AND      #0x0F            ; ...
     ORA      SCORE_PF1+3      ; ...
     STA      SCORE_PF1+3      ; ...

     LDA      DIGITS+4,Y       ; Repeat for 5th line of picture
     AND      #0xF0            ; ...
     STA      SCORE_PF1+4      ; ...
     LDA      DIGITS+4,X       ; ...
     AND      #0x0F            ; ...
     ORA      SCORE_PF1+4      ; ...
     STA      SCORE_PF1+4      ; ...

     LDA      #0               ; For now ...
     STA      SCORE_PF2        ; ... there ...
     STA      SCORE_PF2+1      ; ... is ...
     STA      SCORE_PF2+2      ; ... no ...
     STA      SCORE_PF2+3      ; ... 100s ...
     STA      SCORE_PF2+4      ; ... digit drawn

     RTS                       ; Done

EXPERTISE:

  LDA      #12              ; near the bottom
  STA      PLAYR0Y          ; Player 0 Y coordinate
  RTS                       ; Done

ADJUST_DIF:

     ;  This function adjusts the wall game difficulty values based on the
     ;  current score. The music can also change with the difficulty. A single
     ;  table describes the new values and when they take effect.

     LDX      #0               ; Starting at index 0

AdjNextRow:
     LDA      SKILL_VALUES,X   ; Get the score match
     CMP      #255             ; At the end of the table?
     BNE      AdjCheckTable    ; No ... check this row
     RTS                       ; End of the table ... leave it alone
AdjCheckTable:
     CMP      WALLCNT          ; Is this our row?
     BNE      AdjBump          ; No ... bump to next
     INX                       ; Copy ...
     LDA      SKILL_VALUES,X   ; ... new ...
     STA      WALL_INC         ; ... wall increment
     INX                       ; Copy ...
     LDA      SKILL_VALUES,X   ; ... new ...
     STA      WALLDELY         ; ... wall ...
     STA      WALLDELYR        ; ... delay
     INX                       ; Copy ...
     LDA      SKILL_VALUES,X   ; ... new ...
     STA      GAPBITS          ; ... gap pattern
     RTS                       ; Done
AdjBump:
     INX                       ; Move ...
     INX                       ; ... X ...
     INX                       ; ... to ...
     INX                       ; ... next ...
     INX                       ; ... row of ...
     INX                       ; ... table
     JMP      AdjNextRow       ; Try next row


SEL_RESET_CHK:

     ;  This function checks for changes to the reset/select
     ;  switches and debounces the transitions.
     ;  xxxxxxSR (Select, Reset)

     LDX      DEBOUNCE         ; Get the last value
     LDA      SWCHB            ; New value
     AND      #3               ; Only need bottom 2 bits
     CMP      DEBOUNCE         ; Same as before?
     BEQ      SelDebounce      ; Yes ... return nothing changed
     STA      DEBOUNCE         ; Hold new last value
     EOR      #255             ; Active low to active high
     AND      #3               ; Only need select/reset
     RTS                       ; Return changes
SelDebounce:
     LDA      #0               ; Return 0 ...
     RTS                       ; ... nothing changed


INIT_MUSIC:
PROCESS_MUSIC:
INIT_GO_FX:
PROCESS_GO_FX:
     RTS                       ; Done

SKILL_VALUES:

     ;  This table describes how to change the various
     ;  difficulty parameters as the game progresses.
     ;  For instance, the second entry in the table
     ;  says that when the score is 4, change the values of
     ;  wall-increment to 1, frame-delay to 2, gap-pattern to 0,
     ;  MusicA to 24, and MusicB to 22.

     ;  A 255 on the end of the table indicates the end

     ;       Wall  Inc  Delay   Gap       MA                 MB
     .byte    0,     1,   3,     0  ,0 , 0
     .byte    4,     1,   2,     0  ,0 , 0
     .byte    8,     1,   1,     0  ,0 , 0
     .byte    16,    1,   1,     1  ,0 , 0
     .byte    24,    1,   1,     3  ,0 , 0
     .byte    32,    1,   1,     7  ,0 , 0
     .byte    40,    1,   1,    15  ,0 , 0
     .byte    48,    2,   1,     0  ,0 , 0
     .byte    64,    2,   1,     1  ,0 , 0
     .byte    80,    2,   1,     3  ,0 , 0
     .byte    96 ,   2,   1,     7  ,0 , 0
     .byte    255

GR_PLAYER:
     ;  Image for players (8x8)
     .subs .=0, *=1
     ;
     .byte    0b__...*....
     .byte    0b__...*....
     .byte    0b__..*.*...
     .byte    0b__..*.*...
     .byte    0b__.*.*.*..
     .byte    0b__.*.*.*..
     .byte    0b__*.*.*.*.
     .byte    0b__.*****..

DIGITS:
     ;  Images for numbers
     ;  We only need 5 rows, but the extra space on the end makes each digit 8 rows,
     ;  which makes it the multiplication easier.

     .byte   0b__....***.  ; 0 (leading 0 is blank)
     .byte   0b__....*.*.
     .byte   0b__....*.*.
     .byte   0b__....*.*.
     .byte   0b__....***.
     .byte   0b__........
     .byte   0b__........
     .byte   0b__........

     .byte   0b__..*...*.  ; 1
     .byte   0b__..*...*.
     .byte   0b__..*...*.
     .byte   0b__..*...*.
     .byte   0b__..*...*.
     .byte   0b__........
     .byte   0b__........
     .byte   0b__........

     .byte   0b__***.***.  ; 2
     .byte   0b__..*...*.
     .byte   0b__***.***.
     .byte   0b__*...*...
     .byte   0b__***.***.
     .byte   0b__........
     .byte   0b__........
     .byte   0b__........

     .byte   0b__***.***.  ; 3
     .byte   0b__..*...*.
     .byte   0b__.**..**.
     .byte   0b__..*...*.
     .byte   0b__***.***.
     .byte   0b__........
     .byte   0b__........
     .byte   0b__........

     .byte   0b__*.*.*.*.  ; 4
     .byte   0b__*.*.*.*.
     .byte   0b__***.***.
     .byte   0b__..*...*.
     .byte   0b__..*...*.
     .byte   0b__........
     .byte   0b__........
     .byte   0b__........

     .byte   0b__***.***. ; 5
     .byte   0b__*...*...
     .byte   0b__***.***.
     .byte   0b__..*...*.
     .byte   0b__***.***.
     .byte   0b__........
     .byte   0b__........
     .byte   0b__........

     .byte   0b__***.***. ; 6
     .byte   0b__*...*...
     .byte   0b__***.***.
     .byte   0b__*.*.*.*.
     .byte   0b__***.***.
     .byte   0b__........
     .byte   0b__........
     .byte   0b__........

     .byte   0b__***.***. ; 7
     .byte   0b__..*...*.
     .byte   0b__..*...*.
     .byte   0b__..*...*.
     .byte   0b__..*...*.
     .byte   0b__........
     .byte   0b__........
     .byte   0b__........

     .byte   0b__***.***. ; 8
     .byte   0b__*.*.*.*.
     .byte   0b__***.***.
     .byte   0b__*.*.*.*.
     .byte   0b__***.***.
     .byte   0b__........
     .byte   0b__........
     .byte   0b__........

     .byte   0b__***.***. ; 9
     .byte   0b__*.*.*.*.
     .byte   0b__***.***.
     .byte   0b__..*...*.
     .byte   0b__***.***.
     .byte   0b__........
     .byte   0b__........
     .byte   0b__........

F7FA:
	 ; 6502 vectors
     .word main
     .word main  ; Reset vector (top of program)
     .word main
