.cpu 6502

.include "stella.asm"

;  RAM usage

.tmp0             =     0x80 ; First RAM address
.tmp1             =     +    ; 0x81
.tmp2             =     +    ; 0x82
.tmp3             =     +
.playr0y          =     +
.mustmp1          =     +
.scancnt          =     +
.mode             =     +
.wall_inc         =     +
.wallcnt          =     +
.walldely         =     +
.walldelyr        =     +
.entropya         =     +
.debounce         =     +
.walldrela        =     +
.walldrelb        =     +
.walldrelc        =     +
.wallstart        =     +
.gapbits          =     +
.mus_tmp1         =     +
.mus_tmp0         =     +
.musaind          =     +
.musbind          =     +
.musadel          =     +
.musbdel          =     +
.musavol          =     +
.musbvol          =     +
; This buffer needs 6 bytes total
.score_pf1        =     +
.score_pf1b       =     +
.score_pf1c       =     +
.score_pf1d       =     +
.score_pf1e       =     +
.score_pf1f       =     +

; FC00 through FFFF is 1K

FC00:
MAIN:
         SEI                   ; Turn off interrupts
         CLD                   ; Clear the "decimal" flag

; http:;atariage.com/forums/topic/27405-session-12-initialisation
; Nice, tight code to clear memory and registers at startup
         LDX   #0              ; 0 to ...
         TXS                   ; ... SP
         TXA                   ; 0 to A (for clearing memory)
         PHA                   ; SP is now FF (the end of memory)
Clear:   PHA                   ; Store 0
         DEX                   ; All 256 of memory+registers cleared?
         BNE   Clear           ; No ... do all. SP ends at FF again

         JSR  INIT             ; Initialize game environment
         JSR  INIT_SELMODE     ; Start out in SELECT mode (fall into main loop)

; Start here at the end of every screen frame
;
VIDEO_KERNEL:

	     LDA   #2              ; Wait for ...
	     STA   WSYNC           ; ... the end of the current line
	     STA   VBLANK          ; Turn the beam off
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

         INC   entropya        ; Counting video frames as part of the random number

         LDA   mode            ; What are we doing between frames?
         BEQ   DoGameOvermode  ; 0 is "game over"
         CMP   #1              ; 1 is ...
         BEQ   DoPlaymode      ; ... "game play"
         JSR   SELMODE         ; 2 is "select game"
         JMP   DrawFrame       ; Continue to the visible screen area
         ; JSR/RTS

DoPlaymode:
         JSR   PLAYMODE        ; Playing-game processing
         JMP   DrawFrame       ; Continue to the visible screen area
         ; JSR/RTS

DoGameOvermode:
         JSR   GOMODE          ; Game-over processing (fall into DrawFrame)

DrawFrame:

         ;  ***** LENGTHY GAME LOGIC PROCESSING ENDS HERE *****

         LDA   INTIM           ; Wait for ...
	     BNE   DrawFrame       ; ... of the screen

	     STA   WSYNC           ; 37th scanline
	     LDA   #0              ; Turn the ...
	     STA   VBLANK          ; ... beam back on

	     LDA   #0              ; Zero out ...
	     STA   scancnt         ; ... scanline count ...
	     STA   tmp0            ; ... and all ...
	     STA   tmp1            ; ... returns ...
	     STA   tmp2            ; ... expected ...
	     TAX                   ; ... to come from BUILDROW

	     STA   CXCLR           ; Clear collision detection

DrawVisibleRows:

         ;  BEGIN VISIBLE PART OF FRAME

         LDA   tmp0            ; Get A ready (PF0 value)
	     STA   WSYNC           ; Wait for very start of row
	     STX   GRP0            ; Player 0 graphics (or blank) in X
	     STA   PF0             ; PF0 in tmp0 (already in A)
	     LDA   tmp1            ; PF1 ...
	     STA   PF1             ; ... in tmp1
	     LDA   tmp2            ; PP2 ...
	     STA   PF2             ; ... in tmp2

	     JSR   BUILDROW        ; This MUST take through to the next line

	     INC   scancnt         ; Next scan line
	     LDA   scancnt         ; Do 109*2 = 218 lines
	     CMP   #109            ; All done?
	     BNE   DrawVisibleRows ; No ... get all the visible rows

	     ;  END VISIBLE PART OF FRAME

	     LDA   #0              ; Turn off electron beam
	     STA   WSYNC           ; Next scanline
	     STA   PF0             ; Play field 0 off
	     STA   GRP0            ; Player 0 off
	     STA   PF1             ; Play field 1 off
	     STA   PF2             ; Play field 2 off
	     STA   WSYNC           ; Next scanline

	     JMP   VIDEO_KERNEL    ; Back to top of main loop

BUILDROW:

	     LDA   scancnt         ; Where are we on the screen?

	     CMP   #6              ; If we are in the ...
	     BCC   SHOWSCORE       ; ... score area (nothing else up here)

	     AND   #7              ; Lower 3 bits as an index
	     TAY                   ; Using Y to lookup graphics
	     LDA   GR_PLAYER,Y     ; Get the graphics (if enabled on this row)
	     TAX                   ; Hold it (for return as player 0)
	     LDA   scancnt         ; Scanline count again
	     LSR   A               ; This time ...
	     LSR   A               ; ... we divide ...
	     LSR   A               ; ... by eight (8 rows in picture)

	     CMP   playr0y         ; Scanline group of the P0 object?
	     BEQ   ShowP0          ; Yes ... keep the picture
	     LDX   #0              ; Not time for Player 0 ... no graphics
ShowP0:
         LDA   wallstart       ; Calculate ...
	     CLC                   ; ... the bottom ...
	     ADC   #10             ; ... of ...
	     STA   tmp0            ; ... the wall

	     LDA   scancnt         ; Scanline count

	     CMP   wallstart       ; Past upper part of wall?
	     BCC   NoWall          ; No ... skip it
	     CMP   tmp0            ; Past lower part of wall
	     BCS   NoWall          ; Yes ... skip it

	     ;  The wall is on this row
	     LDA   walldrela       ; Draw wall ...
	     STA   tmp0            ; ... by transfering ...
	     LDA   walldrelb       ; ... playfield ...
	     STA   tmp1            ; ... patterns ...
	     LDA   walldrelc       ; ... to ...
	     STA   tmp2            ; ... return area
	     RTS

NoWall:
	     ;  The wall is NOT on this row
	     LDA   #0              ; No walls on this row
	     STA   tmp0            ; ... clear ...
	     STA   tmp1            ; ... out ...
	     STA   tmp2            ; ... the playfield
	     RTS

SHOWSCORE:
	     AND   #7              ; Only need the lower 3 bits
	     TAY                   ; Soon to be an index into a list

	     ;  At this point, the beam is past the loading of the
	     ;  playfield for the left half. We want to make sure
	     ;  that the right half of the playfield is off, so do that
	     ;  now.

	     LDX   #0              ; Blank bit pattern
	     STX   tmp0            ; This will always be blank
	     STX   PF1             ; Turn off playfield ...
	     STX   PF2             ; ... for right half of the screen

	     TAX                   ; Another index
	     LDA   score_pf1,Y     ; Lookup the PF1 graphics for this row
	     STA   tmp1            ; Return it to the caller
	     TAY                   ; We'll need this value again in a second
	     LDA   #0              ; Blank digit
	     STA   tmp2            ; Return it to the caller

	     STA   WSYNC           ; Now on the next row

	     STY   PF1             ; Repeat the left-side playfield ...
	     STA   PF2             ; ... onto the new row

	     LDX   #6              ; Wait for ...
Delay1:  DEX                   ; ... left half of ...
	     BNE   Delay1          ; ... playfield

	     ;  The beam is past the left half of the field again.
	     ;  Turn off the playfield.

	     STX   PF1             ; 0 to PF1 ...
	     STX   PF2             ; ... and PF2
	     RTS

INIT:
         ;  This function is called ONCE at power-up/reset to initialize various
         ;  game settings and variables.

         LDA   #64             ; Wall is ...
         STA   COLUPF          ; ... redish
         LDA   #126            ; P0 is ...
         STA   COLUP0          ; ... white

         LDA   #5              ; Right half of playfield is reflection of left ...
         STA   CTRLPF          ; ... and playfield is on top of players

         LDX   #10             ; Player 0 position count
         STA   WSYNC           ; Get a fresh scanline

TimeP0Pos:
         DEX                   ; Kill time while the beam moves ...
         BNE   TimeP0Pos       ; ... to position
         STA   RESP0           ; Mark player 0's X position
         LDA   #11             ; near the bottom
         STA   playr0y         ; Player 0 Y coordinate

         LDA   #0              ; Set score to ...
         STA   wallcnt         ; ... 0
         JSR   MAKE_SCORE      ; Blank the score digits
         LDA   #0              ; Blank bits ...
         STA   score_pf1+5     ; ... digit pattern

         JSR   ADJUST_DIF      ; Initialize the wall parameters
         JSR   NEW_GAPS        ; Build the wall's initial gap

         LDA   #112            ; Set wall position off bottom ...
         STA   wallstart       ; ... to force a restart on first move

         LDA   #0              ; Zero out ...
         STA   HMP0            ; ... player 0 motion

         RTS

INIT_PLAYMODE:

         ;  This function initializes the game play mode

         LDA   #192            ; Background is ...
	     STA   COLUBK          ; ... greenish
	     LDA   #1              ; Game mode is ...
	     STA   mode            ; ... SELECT
	     LDA   #255            ; Restart wall score to ...
	     STA   wallcnt         ; ... 0 on first move
	     LDA   #112            ; Force wall to start ...
	     STA   wallstart       ; ... over on first move
	     JMP   INIT_MUSIC      ; Initialize the music and return
	     ; JSR/RTS

PLAYMODE:

         ;  This function is called once per frame to process the main game play.

         JSR   SEL_RESET_CHK   ; Check to see if Reset/Select has changed

         CMP   #0              ; Is select pressed?
         BEQ   NoSelect        ; No ... skip
         STX   debounce        ; Restore the old value ...
         JMP   INIT_SELMODE    ; ... and let select-mode process the toggle and return
         ; JSR/RTS

NoSelect:
	     JSR   PROCESS_MUSIC   ; Process any playing music
	     JSR   MOVE_WALLS      ; Move the walls

	     CMP   #1              ; Wall on first row?
	     BNE   NoFirst         ; No ... move on
	     INC   wallcnt         ; Bump the score
	     JSR   ADJUST_DIF      ; Change the wall parameters based on score
	     LDA   wallcnt         ; Change the ...
	     JSR   MAKE_SCORE      ; ... score pattern
	     JSR   NEW_GAPS        ; Calculate the new gap position

NoFirst:
	     LDA   CXP0FB          ; Player 0 collision with playfield
	     AND   #128            ; Did player hit wall?
	     BEQ   NoHit           ; No ... move on
	     JMP   INIT_GOMODE     ; Go to Game-Over mode

NoHit:
	     LDA   SWCHA           ; Joystick
	     AND   #128            ; Player 0 ... moving left
	     BEQ   MoveP0Left      ; Yes ... move left
	     LDA   SWCHA           ; Joystick
	     AND   #64             ; Player 0 ... moving right?
	     BEQ   MoveP0Right     ; Yes ... move right
	     LDA   #0              ; Not moving value
	     JMP   SetMoveP0       ; Don't move the player
MoveP0Right:
	     LDA   #16             ; +1
	     JMP   SetMoveP0       ; Set HMP0
MoveP0Left:
	     INC   entropya
	     LDA   #240            ; -1
SetMoveP0:
	     STA   HMP0            ; New movement value P0
	     RTS                   

INIT_SELMODE:
	     ;
	     ;  This function initializes the games SELECT-mode
	     ;
	     LDA   #200            ; Background ...
	     STA   COLUBK          ; ... greenish bright
	     LDA   #2              ; Now in ...
	     STA   mode            ; SELECT game mode
Out1:    RTS   

SELMODE:
	     ;
	     ;  This function is called once per frame to process the SELECT-mode.
	     ;  The wall moves here, but doesn't change or collide with players.
	     ;  This function selects between 1 and 2 player game.
	     ;
	     JSR   MOVE_WALLS      ; Move the walls
	     JSR   SEL_RESET_CHK   ; Check the reset/select switches
	     AND   #1              ; RESET button?
	     BEQ   Out1            ; No ... skip
	     JMP   INIT_PLAYMODE   ; Reset toggled ... start game
	     ; JSR/RTS

INIT_GOMODE:
	     ;  This function initializes the GAME-OVER game mode.

         STA   HMCLR           ; Stop both players from moving
         LDA   #0              ; Going to ...
         STA   mode            ; ... game-over mode
         STA   AUDV0           ; Turn off any ...
         STA   AUDV1           ; ... sound
         JSR   INIT_GO_FX      ; Initialize sound effects
         RTS

GOMODE:
	     ; This function is called every frame to process the game
         ; over sequence. When the sound effect has finished, the
         ; game switches to select mode.

         JSR   PROCESS_GO_FX    ; Process the sound effects
         CMP   #0               ; Effects still running?
         BEQ   GoKeepGoing      ; Yes ... let them run
         JSR   INIT_SELMODE     ; When effect is over, go to select mode
         LDA   #0               ; Turn off ...
         STA   AUDV0            ; ... all ...
         STA   AUDV1            ; ... sound
GoKeepGoing:
         RTS

MOVE_WALLS:

	     ;  This function moves the wall down the screen and back to position 0
	     ;  when it reaches (or passes) 112.

	     DEC   walldely        ; Wall motion timer
	     LDA   walldely        ; Time to ...
	     BNE   WallDone        ; No ... leave it alone
	     LDA   walldelyr       ; Reset the ...
	     STA   walldely        ; ... delay count
	     LDA   wallstart       ; Current wall position
	     CLC                   ; Increment ...
	     ADC   wall_inc        ; ... wall position
	     CMP   #112            ; At the bottom?
	     BCC   WallOK          ; No ... leave it alone
	     LDA   #0              ; Else restart ...
	     STA   wallstart       ; ... wall at top of screen
	     LDA   #1              ; Return flag that wall DID restart
	     RTS
WallOK:
     	 STA   wallstart       ; Store new wall position
WallDone:
	     LDA   #0              ; Return flag that wall did NOT restart
	     RTS

NEW_GAPS:
	     ;  This function builds the PF0, PF1, and PF2 graphics for a wall
	     ;  with the gap pattern (gapbits) placed at random in the 20 bit
	     ;  area.

	     LDA   #255            ; Start with ...
	     STA   walldrela       ; ... solid wall in PF0 ...
	     STA   walldrelb       ; ... and PF1
	     LDA   gapbits         ; Store the gap pattern ...
	     STA   walldrelc       ; ... in PF2

         LDA   entropya        ; Get random
         AND   #15             ; 0 to 15
	     CMP   #12             ; Too far to the right?
	     BEQ   GapOK           ; No ... 12 is OK
	     BCC   GapOK           ; No ... less than 12 is OK
	     SBC   #9              ; Back up 9

GapOK:
	     CMP   #0              ; Gap already at far left?
	     BEQ   Out1            ; Yes ... done
	     SEC                   ; Roll gap ...
	     ROR   walldrelc       ; ... left ...
	     ROL   walldrelb       ; ... desired ...
	     ROR   walldrela       ; ... times ...
	     SEC                   ; All rolls ...
	     SBC   #1              ; ... done?
	     JMP   GapOK           ; No ... do them all

MAKE_SCORE:

	     ;  This function builds the PF1 and PF2 graphics rows for
	     ;  the byte value passed in A. The current implementation is
	     ;  two-digits only ... PF2 is blank.

	     LDX   #0              ; 100's digit
	     LDY   #0              ; 10's digit

Count100s:
	     CMP   #100            ; Need another 100s digit?
	     BCC   Count10s        ; No ... move on to 10s
	     INX                   ; Count ...
	     SEC                   ; ... value
	     SBC   #100            ; Take off this 100
	     JMP   Count100s       ; Keep counting
Count10s:
	     CMP   #10             ; Need another 10s digit?
	     BCC   CountDone       ; No ... got all the tens
	     INY                   ; Count ...
	     SEC                   ; ... value
	     SBC   #10             ; Take off this 10
	     JMP   Count10s        ; Keep counting

CountDone:
	     ASL   A               ; One's digit ...
	     ASL   A               ; ... *8 ....
	     ASL   A               ; ... to find picture
	     STA   tmp1
	     TYA                   ; Now the 10's digit
	     ASL   A               ; Multiply ...
	     ASL   A               ; ... by 8 ...
	     ASL   A               ; ... to find picture
	     STA   tmp2            ; 10's picture in Y

	     ; We have plenty of code space. Time and registers are at a premium.
	     ; So copy/past the code for each row

	     LDA   #0              ; Digit row ...
	     STA   tmp3            ; ... counter

ScoreLoop:
	     LDX   tmp2            ; Left most digit
	     LDA   DIGITS,X        ; Get the 10's digit pixels
	     AND   #0xF0           ; Upper nibble
	     STA   tmp0            ; Store left side
	     LDX   tmp1            ; Right most digit
	     LDA   DIGITS,X        ; Get the 1's digit pixels
	     AND   #0x0F           ; Lower nibble
	     ORA   tmp0            ; Put left and right half together
	     LDX   tmp3            ; Row counter
	     STA   score_pf1,X     ; Store calculated image for draw
	     INC   tmp1            ; Next row in right digit
	     INC   tmp2            ; Next row in left digit
	     INC   tmp3            ; Next row count
	     LDA   tmp3            ; Have we finished ...
	     CMP   #5              ; ... all rows?
	     BNE   ScoreLoop       ; No ... do them all

	     RTS

ADJUST_DIF:

	     ;  This function adjusts the wall game difficulty values based on the
	     ;  current score. The music can also change with the difficulty. A single
	     ;  table describes the new values and when they take effect.

	     LDX   #0              ; Starting at index 0

AdjNextRow:
	     LDA   SKILL_VALUES,X  ; Get the score match
	     CMP   #255            ; At the end of the table?
	     BEQ   Out2            ; Yes ... leave it alone

	     CMP   wallcnt         ; Is this our entry?
	     BNE   AdjBump         ; No ... bump to next

	     LDY   #1              ; Increment by 1 ...
	     CMP   #64             ; ... until 64 rows ...
	     BCC   StillLow        ; ... then ...
	     INY                   ; ... by 2
StillLow:
	     STY   wall_inc        ; New increment

	     INX                   ; Copy ...
	     LDA   SKILL_VALUES,X  ; ... new ...
	     STA   walldely        ; ... wall delay
	     STA   walldelyr

	     INX                   ; Copy ...
	     LDA   SKILL_VALUES,X  ; ... new ...
	     STA   gapbits         ; ... gap pattern
Out2:    RTS

AdjBump: TXA                   ; Move ...
	     CLC                   ; ... X to ...
	     ADC   #8              ; ... next ...
	     TAX                   ; ... entry

     	JMP    AdjNextRow      ; Try next row


SEL_RESET_CHK:

	     ;  This function checks for changes to the reset/select
	     ;  switches and debounces the transitions.
	     ;  xxxxxxSR (Select, Reset)

	     LDX   debounce        ; Get the last value
	     LDA   SWCHB           ; New value
	     AND   #3              ; Only need bottom 2 bits
	     CMP   debounce        ; Same as before?
	     BEQ   SelDebounce     ; Yes ... return nothing changed
	     STA   debounce        ; Hold new last value
	     EOR   #255            ; Active low to active high
	     AND   #3              ; Only need select/reset
	     RTS                   ; Return changes
SelDebounce:
	     LDA   #0              ; Return 0 ...
	     RTS                   ; ... nothing changed

INIT_MUSIC:
         ;  This function initializes the hardware and temporaries
         ;  for 2-channel music

         LDA   #12             ; div 6 pure tone ...
         STA   AUDC0           ; ... for musical notes
         LDA   #15             ; Full ...
         STA   musavol         ; ... volume

         LDA   #8              ; 9 bit poly (white noise) ...
         STA   AUDC1           ; ... for drum
         STA   musbvol         ; Half volume

         LDA   #1              ; Force ...
         STA   musadel         ; ... music ...
         STA   musbdel         ; ... reload

         RTS

PROCVCE:
         ROR   A               ; The upper ...
         ROR   A               ; ... three ...
         ROR   A               ; ... bits ...
         ROR   A               ; ... hold ...
         ROR   A               ; ... the ...
         AND   #7              ; ... delay
         CLC                   ; No accidental carry
         ROL   A               ; Every delay tick ...
         ROL   A               ; ... is *4 frames
         RTS

PROCESS_MUSIC:
         ;  This function is called once per frame to process the
         ;  2 channel music. Two tables contain the commands/notes
         ;  for individual channels. This function changes the
         ;  notes at the right time.

         DEC   musadel         ; Current note on Channel A ended?
         BNE   MusDoB          ; No ... let it play

MusChanA:
         LDX   musaind         ; Voice-A index
         LDA   MUSICA,X        ; Get the next music command
         ;CMP   #0              ; Jump?
         BNE   MusCmdToneA     ; Yes ... handle it
         STA   musaind
         JMP   MusChanA        ; Keep processing through a tone

MusCmdToneA:
         LDY   musavol         ; Get the volume
         AND   #0x1F           ; Lower 5 bits are frequency
         CMP   #0x1F           ; Is this a silence?
         BNE   MusNoteA        ; No ... play it
         LDY   #0              ; Frequency of 31 flags silence
MusNoteA:
         STA   AUDF0           ; Store the frequency
         STY   AUDV0           ; Store the volume
         LDA   MUSICA,X        ; Get the note value again
         INC   musaind         ; Bump to the next command
         JSR   PROCVCE
         STA   musadel         ; Store the note delay

; Second voice is just like the first

MusDoB:
         DEC   musbdel
         BNE   MusDoDone

MusChanB:
         LDX   musbind
         LDA   MUSICB,X
         ;CMP   #0
         BNE   MusCmdToneB
         STA   musbind
         JMP   MusChanB

MusCmdToneB:
         LDY   musbvol
         AND   #0x1F
         CMP   #0x1F
         BNE   MusNoteB
         LDY   #0
MusNoteB:
         STA   AUDF1
         STY   AUDV1
         LDA   MUSICB,X
         INC   musbind
         JSR   PROCVCE
         STA   musbdel

MusDoDone:
         RTS

INIT_GO_FX:

         ;  This function initializes the hardware and temporaries
         ;  to play the soundeffect of a player hitting the wall

         LDA   #5               ; Set counter for frame delay ...
         STA   mus_tmp1         ; ... between frequency change
         LDA   #3               ; Tone type ...
         STA   AUDC0            ; ... poly tone
         LDA   #15              ; Volume A ...
         STA   AUDV0            ; ... to max
         LDA   #0               ; Volume B ...
         STA   AUDV1            ; ... silence
         LDA   #240             ; Initial ...
         STA   mus_tmp0         ; ... sound ...
         STA   AUDF0            ; ... frequency
         RTS

PROCESS_GO_FX:

         ;  This function is called once per scanline to play the
         ;  soundeffects of a player hitting the wall.

         DEC   mus_tmp1        ; Time to change the frequency?
         BNE   FxRun           ; No ... let it run
         LDA   #5              ; Reload ...
         STA   mus_tmp1        ; ... the frame count
         INC   mus_tmp0        ; Increment ...
         LDA   mus_tmp0        ; ... the frequency divisor
         STA   AUDF0           ; Change the frequency
         CMP   #0
         BNE   FxRun
         LDA   #1              ; All done ... return 1
         RTS
FxRun:
         LDA   #0              ; Keep playing
         RTS

; Constants used in the music table
.MUSCMD_JUMP      =     0                ; Music command value for JUMP
.MUS_REST         =     31               ; Frequency value for silence
.MUS_DEL_1        =     32*1             ; Note duration 1
.MUS_DEL_2        =     32*2             ; Note duration 2
.MUS_DEL_3        =     32*3             ; Note duration 3
.MUS_DEL_4        =     32*4             ; Note duration 4

MUSICA: ; Tones
     .byte    MUS_DEL_3  +  15
     .byte    MUS_DEL_1  +  MUS_REST
     .byte    MUS_DEL_3  +  15
     .byte    MUS_DEL_1  +  MUS_REST
     .byte    MUS_DEL_1  +  7
     .byte    MUS_DEL_1  +  MUS_REST
     .byte    MUS_DEL_1  +  7
     .byte    MUS_DEL_1  +  MUS_REST
     .byte    MUS_DEL_2  +  MUS_REST
     .byte    MUS_DEL_1  +  8
     .byte    MUS_DEL_1  +  MUS_REST
     .byte    MUS_DEL_4  +  MUS_REST
     .byte    MUS_DEL_2  +  17
     .byte    MUS_DEL_2  +  MUS_REST
     .byte    MUS_DEL_2  +  17
     .byte    MUS_DEL_2  +  MUS_REST
     .byte    MUS_DEL_3  +  16
     .byte    MUS_DEL_1  +  MUS_REST
     .byte    MUSCMD_JUMP

MUSICB: ; Drums
     .byte    MUS_DEL_1  +  10
     .byte    MUS_DEL_1  +  MUS_REST
     .byte    MUS_DEL_1  +  20
     .byte    MUS_DEL_1  +  MUS_REST
     .byte    MUS_DEL_1  +  30
     .byte    MUS_DEL_1  +  MUS_REST
     .byte    MUS_DEL_1  +  15
     .byte    MUS_DEL_1  +  MUS_REST
     .byte    MUS_DEL_1  +  10
     .byte    MUS_DEL_1  +  MUS_REST
     .byte    MUS_DEL_1  +  20
     .byte    MUS_DEL_1  +  MUS_REST
     .byte    MUS_DEL_1  +  30
     .byte    MUS_DEL_1  +  MUS_REST
     .byte    MUS_DEL_1  +  15
     .byte    MUS_DEL_1  +  MUS_REST
     .byte    MUSCMD_JUMP

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
	     ;  Images for numbers:
	     ;  We only need 5 rows, but the extra space on the end makes each digit 8 rows,
	     ;  which makes it the multiplication easier.

	     ;  The skill-adjustment table is woven into the digits. Each
	     ;  digit has 3 bytes wasted for easy lookup-math. The rows
	     ;  of the adjustment table fit nicely.
	     ;
	     ;  This table describes how to change the various
	     ;  difficulty parameters as the game progresses.
	     ;  For instance, the second entry in the table
	     ;  says that when the score is 4, change the values of
	     ;  wall-increment to 1, frame-delay to 2, and gap-pattern
	     ;  to 0. A 255 on the end of the table indicates the end.
	     ;
	     ;  For example:
	     ;        Wall     Delay    Gap
	     ; .byte    5,        3,     7

	     .byte   0b__....***.  ; 0 (leading 0 is blank)
	     .byte   0b__....*.*.
	     .byte   0b__....*.*.
	     .byte   0b__....*.*.
	     .byte   0b__....***.
SKILL_VALUES:
	     .byte    0, 3, 0

	     .byte   0b__..*...*.  ; 1
	     .byte   0b__..*...*.
	     .byte   0b__..*...*.
	     .byte   0b__..*...*.
	     .byte   0b__..*...*.
	     ;
	     .byte   4, 2, 0

	     .byte   0b__***.***.  ; 2
	     .byte   0b__..*...*.
	     .byte   0b__***.***.
	     .byte   0b__*...*...
	     .byte   0b__***.***.
	     ;
	     .byte   12, 2, 1

	     .byte   0b__***.***.  ; 3
	     .byte   0b__..*...*.
	     .byte   0b__.**..**.
	     .byte   0b__..*...*.
	     .byte   0b__***.***.
	     ;
	     .byte   24, 1, 3

	     .byte   0b__*.*.*.*.  ; 4
	     .byte   0b__*.*.*.*.
	     .byte   0b__***.***.
	     .byte   0b__..*...*.
	     .byte   0b__..*...*.
	     ;
	     .byte   32, 1, 7

	     .byte   0b__***.***. ; 5
	     .byte   0b__*...*...
	     .byte   0b__***.***.
	     .byte   0b__..*...*.
	     .byte   0b__***.***.
	     ;
	     .byte   40, 1, 15

	     .byte   0b__***.***. ; 6
	     .byte   0b__*...*...
	     .byte   0b__***.***.
	     .byte   0b__*.*.*.*.
	     .byte   0b__***.***.
	     ;
	     .byte   64, 1, 1

	     .byte   0b__***.***. ; 7
	     .byte   0b__..*...*.
	     .byte   0b__..*...*.
	     .byte   0b__..*...*.
	     .byte   0b__..*...*.
	     ;
	     .byte   80, 1, 3

	     .byte   0b__***.***. ; 8
	     .byte   0b__*.*.*.*.
	     .byte   0b__***.***.
	     .byte   0b__*.*.*.*.
	     .byte   0b__***.***.
	     ;
	     .byte   96, 1, 7

	     .byte   0b__***.***. ; 9
	     .byte   0b__*.*.*.*.
	     .byte   0b__***.***.
	     .byte   0b__..*...*.
	     .byte   0b__***.***.
	     ;
LAST:    .byte   255

; 6502 vectors
FFFA:    .word MAIN
	     .word MAIN  ; Reset vector (top of program)
	     .word MAIN
