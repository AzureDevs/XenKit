import MuseScore 3.0
import QtQuick 2.9
import FileIO 3.0

MuseScore {
  menuPath: "Plugins.XenKit"
  description: "Configurable multipurpose xenharmonic tuner for Musescore"
  version: "1.0"


  function getOctave (note) {
    /**
     * Returns the octave of the note, with the 4th octave being 0
     *
     * note - musescore note
     */
    const offset = (note.tpc === 0 || note.tpc === 7) ? 1 : (note.tpc === 26 || note.tpc === 33) ? -1 : 0;
    return Math.floor(note.pitch / 12) - 5 + offset;
  }

  function calcOffset (interval, note, accidental) {
    /**
     * Returns the offset of a note in cents
     * 
     * interval - target interval ratio, including modifiers
     * note - musescore note
     * accidental - musescore accidental enum, for version 4.2+ to counter the default offset
     */
    const middleC = 440 * Math.pow(2, -9/12);
    const targetHz = middleC * interval;
    const pitchHz = Math.pow(2, ((note.pitch - 69)/12)) * 440;

    // MS 4.2+ (offsets from xentuner plugin)
    const base = ((mscoreMajorVersion == 4 && mscoreMinorVersion >= 2) || mscoreMajorVersion > 4) ? ([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -50, -150, 50, -50, 150, 50, 250, 150, -150, -250, -50, 50, -50, -150, 50, 150, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -6.8, 6.8, -3.4, 3.4, -16.5, 16.5, -1.7, 1.7, -10.9, 10.9, 33, -67, -167, 167, -183, 183, -17, 17, -33, 33, -50, 50, -67, 67, -83, 83, 0, 0, -116, 116, -133, 133, -150, 150, -5.8, 5.8, -21.5, 21.5, -27.3, 27.3, -43, 43, -48.8, 48.8, -53.3, 53.3, -60.4, 60.4, -64.9, 64.9, -70.7, 70.7, -86.4, 86.4, -92.2, 92.2, -107.9, 107.9, -113.7, 113.7, -22.2, 22.2, -44.4, 44.4, -66.7, 66.7, -88.9, 111.1][0 + accidental] || 0) : 0;

    return Math.log(targetHz / pitchHz) / Math.log(2) * 1200 - base;
  }
  
  function parseInterval (v, params) {
    /**
     * parses a combination of cents, steps, ratios, monzos, accidentals, or commas into a ratio
     * returns false if v is not of a valid combination of the listed types
     * 
     * v - the interval to parse
     * params - tuning params for accidentals
     */
    
    const primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97];
    const commas = {
      // follows HEJI
      "5": [81/80, -1],
      "7": [64/63, -1],
      "11": [33/32, 1],
      "13": [27/26, -1],
      // WIP: check signs
      "17":	[2187/2176, 1],
      "19":	[513/512, 1],
      "23":	[736/729, 1],
      "29":	[261/256, 1],
      "31":	[32/31, 1],
      "37":	[37/36, 1],
      "41":	[82/81],
      "43":	[129/128],
      "47":	[752/729]
    };
    const accidentals = {
      "#": (params && params.apotome) || 2187/2048,
      "b": params && params.apotome ? 1 / params.apotome : 2048/2187,
      "x": Math.pow((params && params.apotome) || 2187/2048, 2),
      "^": (params && params.stepSize) || 1,
      "v": params && params.stepSize ? 1 / params.stepSize : 1
    };

    
    var prod = 1;

    const relativity = v[0] === "*" ? 1 : v[0] === "=" ? 0 : -1;
    if (relativity !== -1) v = v.slice(1).trim();
    
    v = v.trim().replace(/&gt;/g, ">").replace(/–/g, "-" /* dashes for negative */);
    for (var i = 0; i < v.length; i++) {
      if (/[\s\*]/.test(v[i])) continue;
      if (v[i] === "[" && /^\[\s*-?\d+([\s,]+-?\d+)*\s*>/.test(v.slice(i))) {
        // monzo
        const arr = v.slice(i + 1, i = v.indexOf(">", i)).trim().split(/[\s,]+/).map(Number);
        if (arr.length > primes.length) return false; // monzo must be 97-limit!
        arr.forEach(function (pow, i) {
          prod *= Math.pow(primes[i], pow);
        });
        continue;
      }
      if (/^S\d+/.test(v.slice(i))) {
        // superparticular
        const index = v.slice(i + 1, i += v.slice(i + 1).search(/(\D|$)/) + 1);
        prod *= Math.pow(index, 2) / (Math.pow(index, 2) - 1);
        i--;
        continue;
      }
      if (/^-?\d+(\.\d+)?\s*[c¢]/.test(v.slice(i))) {
        // cents
        prod *= Math.pow(2, Number(v.slice(i, i += v.slice(i).search(/[c¢]/))) / 1200);
        continue;
      }
      if (/^-?\d+\\\d+/.test(v.slice(i))) {
        // steps
        const frac = v.slice(i, v.indexOf("\\", i) + 1 + v.slice(v.indexOf("\\", i) + 1).search(/(\D|$)/)).split("\\");
        prod *= Math.pow(2, Number(frac[0]) / Number(frac[1]));
        i += frac.join("").length;
        continue;
      }
      if (/^\d+\/\d+/.test(v.slice(i))) {
        // ratio
        const frac = v.slice(i, v.indexOf("/", i) + 1 + v.slice(v.indexOf("/", i) + 1).search(/(\D|$)/)).split("/");
        prod *= Number(frac[0]) / Number(frac[1]);
        i += frac.join("").length;
        continue;
      }
      if (/^[\^v]?\d+,/.test(v.slice(i))) {
        // potential comma
        const sign = v[i] === "^" ? 1 : v[i] === "v" ? -1 : false;
        const comma = v.slice(/\d/.test(v[i]) ? i : i + 1, i = v.indexOf(",", i));
        if (commas[comma]) prod *= Math.pow(commas[comma][0], sign || commas[comma][1]);
        else return false; // invalid comma
        continue;
      }
      if (/^\d*[#bx\^v]/.test(v.slice(i))) {
        // accidentals
        const quantifier = Number(v.slice(i, i += v.slice(i).search(/[#bx\^v]/))) || 1;
        prod *= Math.pow(accidentals[v.charAt(i)], quantifier);
        continue;
      }

      return false; // all else failed, terminate parser
    }
    
    return [prod, relativity];
  }

  function parseKeySig (sig, params) {
    /**
     * Parses a key signature string into an array
     *
     * sig - the key signature to parse
     * params - tuning parameters for accidentals
     */

    // check for a global multiplier ...
    var glob = [1, -1];
    if (sig.match(/\.\.\./) && sig.match(/\.\.\./g).length === 1) {
      glob = parseInterval(sig.split("...")[1], params);
      sig = sig.split("...")[0];
      
      if (!glob) return false;
      if (!sig.trim()) return [glob, glob, glob, glob, glob, glob, glob]; // lone global
    }

    // global multipliers attached to key signatures must not contain a relativity symbol
    if (glob[1] !== -1) return false;
    
    if (!sig.match(/\|/) || sig.match(/\|/g).length !== 6) return false;
    sig = sig.split("|").map(function (v) {
      v = parseInterval(v, params);
      return [v[0] && v[0] * glob[0], v[1]];
    });
    return sig.indexOf(false) === -1 && sig;
  }

  function getAccidental (accidental, params) {
    /**
     * gets the ratio of an accidental of a note, using the enumerator for MuseScore 4
     *
     * accidental - note.accidentalType
     * params - tuning parameters object, if tuning is an edo
     */


    const SHARP = (params && params.apotome) || 2187/2048, _5C = (params && params.stepSize) || 81/80, _7C = 64/63, _11C = 33/32, _13C = 27/26, _17C = 2187/2176, _19C = 513/512, _23C = 736/729, _31C = 32/31;
    const accidentals = {
      NONE:    1,
      NATURAL: 1,

      SHARP:           SHARP,
      FLAT:   Math.pow(SHARP, -1),
      SHARP2: Math.pow(SHARP,  2),
      FLAT2:  Math.pow(SHARP, -2),
      SHARP3: Math.pow(SHARP,  3),
      FLAT3:  Math.pow(SHARP, -3),

      NATURAL_SHARP:    SHARP,
      NATURAL_FLAT: 1 / SHARP,

      SHARP_SHARP: Math.pow(SHARP, 2),

      ARROW_UP:                                _5C,
      ARROW_DOWN:                          1 / _5C,
      NATURAL_ARROW_UP:                        _5C,
      NATURAL_ARROW_DOWN:                  1 / _5C,
      SHARP_ARROW_UP:             SHARP      * _5C,
      SHARP_ARROW_DOWN:           SHARP      / _5C,
      FLAT_ARROW_UP:     Math.pow(SHARP, -1) * _5C,
      FLAT_ARROW_DOWN:   Math.pow(SHARP, -1) / _5C,
      SHARP2_ARROW_UP:   Math.pow(SHARP,  2) * _5C,
      SHARP2_ARROW_DOWN: Math.pow(SHARP,  2) / _5C,
      FLAT2_ARROW_UP:    Math.pow(SHARP, -2) * _5C,
      FLAT2_ARROW_DOWN:  Math.pow(SHARP, -2) / _5C,
      
      /*
      MIRRORED_FLAT: 
      MIRRORED_FLAT2: 
      SHARP_SLASH: 
      SHARP_SLASH4: 
      FLAT_SLASH2: 
      FLAT_SLASH: 
      SHARP_SLASH3: 
      SHARP_SLASH2: 
      */

      DOUBLE_FLAT_ONE_ARROW_DOWN:  Math.pow(SHARP, -2) * Math.pow(_5C, -1),
      FLAT_ONE_ARROW_DOWN:         Math.pow(SHARP, -1) * Math.pow(_5C, -1),
      NATURAL_ONE_ARROW_DOWN:                            Math.pow(_5C, -1),
      SHARP_ONE_ARROW_DOWN:                 SHARP      * Math.pow(_5C, -1),
      DOUBLE_SHARP_ONE_ARROW_DOWN: Math.pow(SHARP,  2) * Math.pow(_5C, -1),

      DOUBLE_FLAT_ONE_ARROW_UP:  Math.pow(SHARP, -2) * _5C,
      FLAT_ONE_ARROW_UP:         Math.pow(SHARP, -1) * _5C,
      NATURAL_ONE_ARROW_UP:                            _5C,
      SHARP_ONE_ARROW_UP:                 SHARP      * _5C,
      DOUBLE_SHARP_ONE_ARROW_UP: Math.pow(SHARP,  2) * _5C,

      DOUBLE_FLAT_TWO_ARROWS_DOWN:  Math.pow(SHARP, -2) * Math.pow(_5C, -2),
      FLAT_TWO_ARROWS_DOWN:         Math.pow(SHARP, -1) * Math.pow(_5C, -2),
      NATURAL_TWO_ARROWS_DOWN:                            Math.pow(_5C, -2),
      SHARP_TWO_ARROWS_DOWN:                 SHARP      * Math.pow(_5C, -2),
      DOUBLE_SHARP_TWO_ARROWS_DOWN: Math.pow(SHARP,  2) * Math.pow(_5C, -2),

      DOUBLE_FLAT_TWO_ARROWS_UP:  Math.pow(SHARP, -2) * Math.pow(_5C, 2),
      FLAT_TWO_ARROWS_UP:         Math.pow(SHARP, -1) * Math.pow(_5C, 2),
      NATURAL_TWO_ARROWS_UP:                            Math.pow(_5C, 2),
      SHARP_TWO_ARROWS_UP:                 SHARP      * Math.pow(_5C, 2),
      DOUBLE_SHARP_TWO_ARROWS_UP: Math.pow(SHARP,  2) * Math.pow(_5C, 2),

      DOUBLE_FLAT_THREE_ARROWS_DOWN:  Math.pow(SHARP, -2) * Math.pow(_5C, -3),
      FLAT_THREE_ARROWS_DOWN:         Math.pow(SHARP, -1) * Math.pow(_5C, -3),
      NATURAL_THREE_ARROWS_DOWN:                            Math.pow(_5C, -3),
      SHARP_THREE_ARROWS_DOWN:                 SHARP      * Math.pow(_5C, -3),
      DOUBLE_SHARP_THREE_ARROWS_DOWN: Math.pow(SHARP,  2) * Math.pow(_5C, -3),

      DOUBLE_FLAT_THREE_ARROWS_UP:  Math.pow(SHARP, -2) * Math.pow(_5C, 3),
      FLAT_THREE_ARROWS_UP:         Math.pow(SHARP, -1) * Math.pow(_5C, 3),
      NATURAL_THREE_ARROWS_UP:                            Math.pow(_5C, 3),
      SHARP_THREE_ARROWS_UP:                 SHARP      * Math.pow(_5C, 3),
      DOUBLE_SHARP_THREE_ARROWS_UP: Math.pow(SHARP,  2) * Math.pow(_5C, 3),

      LOWER_ONE_SEPTIMAL_COMMA:  Math.pow(_7C, -1),
      RAISE_ONE_SEPTIMAL_COMMA:           _7C,
      LOWER_TWO_SEPTIMAL_COMMAS: Math.pow(_7C, -2),
      RAISE_TWO_SEPTIMAL_COMMAS: Math.pow(_7C,  2),

      LOWER_ONE_UNDECIMAL_QUARTERTONE: 1 / _11C,
      RAISE_ONE_UNDECIMAL_QUARTERTONE:     _11C,

      LOWER_ONE_TRIDECIMAL_QUARTERTONE: 1 / _13C,
      RAISE_ONE_TRIDECIMAL_QUARTERTONE:     _13C,

      FLAT_17: 1 / _17C,
      SHARP_17:    _17C,
      FLAT_19: 1 / _19C,
      SHARP_19:    _19C,
      FLAT_23: 1 / _23C,
      SHARP_23:    _23C,
      FLAT_31: 1 / _31C,
      SHARP_31:    _31C,
      // not sure if there is a 53-limit interval for HEJI
      // FLAT_53: 1 / _53C,
      // SHARP_53:    _53C,

      /*
      DOUBLE_FLAT_EQUAL_TEMPERED: 
      FLAT_EQUAL_TEMPERED: 
      NATURAL_EQUAL_TEMPERED: 
      SHARP_EQUAL_TEMPERED: 
      DOUBLE_SHARP_EQUAL_TEMPERED: 
      QUARTER_FLAT_EQUAL_TEMPERED: 
      QUARTER_SHARP_EQUAL_TEMPERED: 

      SORI: 
      KORON: 

      TEN_TWELFTH_FLAT: 
      TEN_TWELFTH_SHARP: 
      ELEVEN_TWELFTH_FLAT: 
      ELEVEN_TWELFTH_SHARP: 
      ONE_TWELFTH_FLAT: 
      ONE_TWELFTH_SHARP: 
      TWO_TWELFTH_FLAT: 
      TWO_TWELFTH_SHARP: 
      THREE_TWELFTH_FLAT: 
      THREE_TWELFTH_SHARP: 
      FOUR_TWELFTH_FLAT: 
      FOUR_TWELFTH_SHARP: 
      FIVE_TWELFTH_FLAT: 
      FIVE_TWELFTH_SHARP: 
      SIX_TWELFTH_FLAT: 
      SIX_TWELFTH_SHARP: 
      SEVEN_TWELFTH_FLAT: 
      SEVEN_TWELFTH_SHARP: 
      EIGHT_TWELFTH_FLAT: 
      EIGHT_TWELFTH_SHARP: 
      NINE_TWELFTH_FLAT: 
      NINE_TWELFTH_SHARP: 
      */

      /* WIP
      SAGITTAL_5V7KD: 
      SAGITTAL_5V7KU: 
      SAGITTAL_5CD: 1 / _5C,
      SAGITTAL_5CU:     _5C,
      SAGITTAL_7CD: 1 / _7C,
      SAGITTAL_7CU:     _7C,
      SAGITTAL_25SDD: Math.pow(_5C, -2),
      SAGITTAL_25SDU: Math.pow(_5C,  2),
      SAGITTAL_35MDD: 1 / _5C / _7C,
      SAGITTAL_35MDU:     _5C * _7C,
      SAGITTAL_11MDD: 1 / _11C,
      SAGITTAL_11MDU:      11C,
      SAGITTAL_11LDD: 
      SAGITTAL_11LDU: 
      SAGITTAL_35LDD: 
      SAGITTAL_35LDU: 
      SAGITTAL_FLAT25SU: Math.pow(SHARP, -1) / _5C,
      SAGITTAL_SHARP25SD: SHARP * _5C,
      SAGITTAL_FLAT7CU: Math.pow(SHARP, -1) / _7C,
      SAGITTAL_SHARP7CD: SHARP * _7C,
      SAGITTAL_SHARP5CD: SHARP * _5C,
      SAGITTAL_SHARP5V7KD: SHARP * 1.02, // Approximation
      SAGITTAL_FLAT5CU: Math.pow(SHARP, -1) / _5C,
      SAGITTAL_FLAT5V7KU: Math.pow(SHARP, -1) * 0.98, // Approximation
      SAGITTAL_FLAT: 1 / SHARP,
      SAGITTAL_SHARP:    SHARP
      */
    };

    if (accidentals[accidental]) return accidentals[accidental];

    // try the enum instead
    for (var acc in accidentals) {
      if (accidental == Accidental[acc]) return accidentals[acc];
    }

    return 1;
  }

  function calcParams (edo) {
    /* Calculates tuning parameters for EDOs
     * returns an object with the stepSize, the apotome, and naturals in ratios
     *
     * edo - int
     */

    // method from tune n-edo plugin based on TallKite's chain of fifths notation
    // similar to the tune n-edo plugin
    const stepSize = Math.pow(2, 1 / edo); // ratio
    const fifth = Math.round(Math.log(3) / Math.log(2) * edo) - edo; // in steps
    const apotome = Math.pow(stepSize, 7 * fifth - 4 * edo);
    const naturals = [
      0,
      (2 * fifth) % edo,
      (4 * fifth) % edo,
      edo - fifth,
      fifth,
      (3 * fifth) % edo,
      (5 * fifth) % edo
    ].map(function (i) {
      return Math.pow(stepSize, i);
    });

    return { stepSize: stepSize, apotome: apotome, naturals: naturals };
  }

  function tune (note, keysig, accidentalMap, lyric, relativity, params) {
    /**
     * Tunes the note
     *
     * note - musescore note
     * keysig - the active key signature
     * accidentalMap - the accidental map
     * lyric - the lyric accidental [v, rel]
     * relativity - the default relativity
     * params - tuning params, if edo
     */

    const naturals = (params && params.naturals) || [1, 9/8, 81/64, 4/3, 3/2, 27/16, 243/128];

    const natural = [0, 4, 1, 5, 2, 6, 3][(note.tpc + 7) % 7];
    const octave = getOctave(note);

    // update the accidental array relatively
    var accidental = getAccidental(note.accidentalType, params);
    if (!accidentalMap[octave * 7 + natural] && note.accidentalType == Accidental.NONE) accidentalMap[octave * 7 + natural] = 1;
    if (note.accidentalType == Accidental.NATURAL) accidentalMap[octave * 7 + natural] = relativity ? 1 : 1 / keysig[natural];
    else if (note.accidentalType != Accidental.NONE) {
      if (relativity) accidentalMap[octave * 7 + natural] = (accidentalMap[octave * 7 + natural] || 1) * accidental;
      else accidentalMap[octave * 7 + natural] = accidental / keysig[natural];
    }

    // check for tied notes (broken, WIP)
    var tiedNote = note;
    while (tiedNote.tieBack) {
      tiedNote = tiedNote.tieBack.startNote;
      accidental = tiedNote.accidentalType;
      // WIP: check the annotation accidentals too
    }

    curScore.startCmd();

    // calculate the written accidental and keysig
    var v = accidentalMap[octave * 7 + natural] * keysig[natural];

    // calculate the lyric accidental
    if (lyric) {
      if (lyric[1] === -1 ? relativity : lyric[1]) v *= lyric[0]; // relative
      else v = lyric[0]; // absolute, override the written accidental
    }

    // base
    v *= naturals[natural] * Math.pow(2, octave);

    note.tuning = calcOffset(v, note, note.accidentalType); // note: an accidentalMap to offset the default effective accidental (MS 4.2+) is not required because of the relative tuning :D
    curScore.endCmd();

    log("Tuned a note to " + Math.round(note.tuning * 1000) / 1000);
    
    return note.tuning;
  }

  function tuneChord (chord, keysig, accidentalMap, relativity, params) {
    /**
     * Tunes the chord
     *
     * chord - musescore chord
     * keysig - the active key signature
     * accidentalMap - the accidental map
     * relativity - the default relativity
     * params- tuning parameters, if edo
     */

    // tune each note
    for (var i = 0; i < chord.notes.length; i++) {
      // grab any annotation accidentals
      const lyric = chord.lyrics[i] ? parseInterval(chord.lyrics[i].text, params) || false : false;
      if (lyric) log("Tuned an annotation " + chord.lyrics[i].text.replace(/&gt;/g, ">") + " to " + lyric);

      tune(chord.notes[i], keysig, accidentalMap, lyric, relativity, params);
    }

    // tune each grace note
    for (var i = 0; i < chord.graceNotes.length; i++) {
      for(var j = 0; j < chord.graceNotes[i].length; j++) {
        // grab any annotation accidentals
        const lyric = chord.lyrics[i * chord.graceNotes.length + j + chord.notes.length] ? parseInterval(chord.lyrics[i * chord.graceNotes.length + j + chord.notes.length].text, params) || false : false;

        tune(chord.graceNotes[i].notes[j], keysig, accidentalMap, lyric, relativity, params);
      }
    }
  }

  function readAnnotations (annotations) {
    /**
     * Checks the annotations for a potential new key signature, a change in default relativity, a new temperament, or config settings
     * returns a key signature with relativity
     *
     * annotations - the annotations object
     */

    const map = {};
    for (var i = 0; i < annotations.length; i++) {
      if (!annotations[i].text) continue;
      const text = annotations[i].text.trim();

      // check key sig
      if (parseKeySig(text, false)) map.keysig = text;

      // check relativity
      if (/^(Use\s+)?Relative(\s+Tuning)?$/i.test(text)) map.relativity = 1;
      if (/^(Use\s+)?Absolute(\s+Tuning)?$/i.test(text)) map.relativity = 0;

      // check temperament
      if (/^(JI|Just\s+Intonation|Pythagorean)$/i.test(text)) map.temperament = "JI";
      if (/^\d+(-|\s+)?(ED[O2]|Equal\s+Divisions\s+of\s+an\s+Octave|T?ET|Tone\s+Equal\s+Temperament)$/i.test(text)) map.temperament = text.match(/(\d+)/i)[0];

      // TODO: check new temperament and config settings
    }
    return map;
  }

  function getFromMap (tick, map) {
    /**
     * Finds active state given a map
     * Used to fetch the key signatures and other annotations for voices 2-4
     *
     * tick - cursor.tick
     * map - map containing the tick and data
     */
    for (var i = 0; i < map.length; i++) {
      if (map[i][0] <= tick && (!map[i + 1] || map[i + 1][0] > tick)) return map[i][1];
    }
    return [1, 1, 1, 1, 1, 1, 1];
  }

  function qtQuit () {
    (typeof(quit) === 'undefined' ? Qt.quit : quit)();
  }

  function log (msg, wipe) {
    /**
     * Writes to the log and console
     *
     * msg - the message to write
     * wipe - wipe the logs if true
     */
    console.log(msg);
    return;
    logs.write((!wipe ? logs.read().replace(/\n+/g, "\n") : "") + msg);
  }


  onRun: {
    log("Tuner started running", true);

    try {

      const cursor = curScore.newCursor();

      const keysigMap = [ [ 0, [1, 1, 1, 1, 1, 1, 1] ] ],
            relativityMap = [ [ 0, 0 ] ], // relativity is off by default
            paramsMap = [ [ 0, calcParams(12) ] ]; // default temperament is 12EDO

      // loop through each part to find drum parts, and ignore during tuning
      const drums = [];
      for (const part of Object.values(cursor.score.parts)) {
        if (part.hasDrumStaff) drums.push(Math.floor(part.startTrack / 4)); // assume all drumsets only have 1 staff!
      }
      log("DRUMS:");
      log(JSON.stringify(drums));

      // loop through each staff
      for (var i = 0; i < curScore.nstaves * 4; i++) {
        // is a drum? too bad
        if (drums.includes(Math.floor(i % 4))) continue;

        log("----- Track " + i + " -----");
        cursor.track = i;
        cursor.rewind(Cursor.SCORE_START);

        var accidentalMap, measure;

        while (cursor.segment) {
          // check for a new measure to reset accidentals
          if (!cursor.measure.is(measure)) {
            log("-m");
            measure = cursor.measure;
            accidentalMap = {};
          }

          const annotations = readAnnotations(cursor.segment.annotations);

          // check for a new temperament
          if (annotations.temperament !== undefined && i === 0) {
            if (cursor.tick === 0) paramsMap.pop();
            if (annotations.temperament === "JI") paramsMap.push([cursor.tick, false]);
            else paramsMap.push([cursor.tick, calcParams(Number(annotations.temperament))]);
            log("Changed temperament to " + annotations.temperament);
            log(JSON.stringify(paramsMap));
          }
          const params = getFromMap(cursor.tick, paramsMap);

          // check for new default relativity
          if (annotations.relativity !== undefined && i === 0) {
            if (cursor.tick === 0) relativityMap.pop();
            relativityMap.push([cursor.tick, annotations.relativity]);
            log("Changed default relativity to " + annotations.relativity);
          }
          const relativity = getFromMap(cursor.tick, relativityMap);
          
          // check for a new key
          var keysig = getFromMap(cursor.tick, keysigMap);
          if (i === 0) {
            const newKey = annotations.keysig && parseKeySig(annotations.keysig, params);
            if (newKey) {
              if (cursor.tick === 0) keysigMap.pop();
              keysigMap.push([cursor.tick, keysig = keysig.map(function (v, i) {
                const r = newKey[i][1] === -1 ? relativity : newKey[i][1];
                return (r ? v : 1) * newKey[i][0];
              })]);
              log(JSON.stringify(keysigMap));
            }
          }

          // tune each chord
          if (cursor.element.type === Element.CHORD) {
            tuneChord(cursor.element, keysig, accidentalMap, relativity, params);
          }

          cursor.next();
        }
      }

      log("Tuner finished running");
      qtQuit();

    } catch (e) { 
      log("ERROR: " + e);
      qtQuit();
    }
  }

  Component.onCompleted: {
    if (mscoreMajorVersion >= 4) {
      if (mscoreMinorVersion >= 4) {
        title: "XenKit"
      } else {
        title = qsTr("XenKit");
      }
      //thumbnailName = "some_thumbnail.png";
      categoryCode = "playback";
    }
  }

  FileIO {
    id: "logs"
    source: homePath() + "/Documents/MuseScore4/Plugins/XenKit/logs.txt"
    onError: {
      console.log(msg);
    }
  }
}
