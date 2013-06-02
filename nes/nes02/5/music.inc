.if .not .defined(CPUFREQ)
	; Frequency of the CPU in Hz; this is an NTSC NES:
	.define CPUFREQ	 1789773
.endif

; Define note-to-semitone mapping:
.enum MusicalNote
	mC = 1
	mD = 3
	mE = 5
	mF = 6
	mG = 8
	mA = 10
	mB = 12
.endenum

.enum Semitone
	; Octave 4 (i.e. C4..B4)
	m0 = 24694	; B(3)
	m1 = 26163	; C
	m2 = 27718	; C#
	m3 = 29366	; D
	m4 = 31113	; D#
	m5 = 32963	; E
	m6 = 34923	; F
	m7 = 36999	; F#
	m8 = 39200	; G
	m9 = 41530	; G#
	m10 = 44000	; A
	m11 = 46616	; A#
	m12 = 49388	; B
	m13 = 52325	; C(5)
.endenum

.macro  Notes	Score
	.repeat (.strlen(Score) / 3), I
		; Extract the definition of the note (prime letter, octave number, and accidental):
		_note_prime_ .set .strat(Score, I*3)
		_note_octave_ .set .strat(Score, I*3+1)-'4'
		_note_acc_ .set .strat(Score, I*3+2)
		.if (_note_prime_ = '_')
			; Rest.
			.dbyt $FEFF
		.else
			; Convert prime letter into a semitone number:
			_note_semi_ .set MusicalNote :: .ident( .concat( "m", .sprintf("%c", _note_prime_)))
			; Offset semitone by accidental (sharp or flat):
			.if (_note_acc_ = '+' .or _note_acc_ = '#')
				; Sharp.
				_note_semi_ .set _note_semi_ + 1
			.elseif (_note_acc_ = '-' .or _note_acc_ = 'b')
				; Flat.
				_note_semi_ .set _note_semi_ - 1
			.endif
			; Get the base frequency of this semitone:
			_semi_freq_ .set Semitone :: .ident( .concat( "m", .sprintf("%d", _note_semi_)))
			; Calculate the base timer...
			.if (_note_octave_ < 0)
				; Shift down by octave(s)
				_timer_ .set (((CPUFREQ << -_note_octave_) * 100) / (16 * _semi_freq_)) - 1
			.else
				; Shift up by octave(s)
				_timer_ .set ((CPUFREQ * 100) / (16 * (_semi_freq_ << _note_octave_))) - 1
			.endif
			; Store timer as big-endian (so we could put $FF in first byte to indicate EOF).
			.dbyt _timer_
		.endif
	.endrep
.endmacro
