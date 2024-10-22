import 'package:audioplayers/audioplayers.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kelimeeslestirme/ad_helper.dart';
import 'package:kelimeeslestirme/word_pairs.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Hafıza için

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();
  runApp(WordMatchGame());
}

class WordMatchGame extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kelime Eşleştirme Oyunu',
      home: WordMatchGameScreen(), // Scaffold burada tanımlanmalı
    );
  }
}

class WordMatchGameScreen extends StatefulWidget {
  @override
  _WordMatchGameScreenState createState() => _WordMatchGameScreenState();
}

class _WordMatchGameScreenState extends State<WordMatchGameScreen> {
  static const platform =
      MethodChannel('com.orionapp.kelimeeslestirme/text_to_speech');

  final FlutterTts flutterTts = FlutterTts();

  Future<void> speak(String text) async {
    try {
      await flutterTts.setLanguage(
          "en-US"); // Dili ayarlayın (Türkçe için "tr-TR" kullanabilirsiniz)
      await flutterTts
          .setPitch(1.0); // Ses tonunu ayarlayın (0.5 - 2.0 arasında)
      await flutterTts.speak(text); // Metni oku
    } catch (e) {
      print("Failed to speak: '${e.toString()}'.");
    }
  }

  Future<void> playMp3(String mp3File) async {
    final AudioPlayer audioPlayer = AudioPlayer();

    try {
      await audioPlayer.play(AssetSource(
          mp3File)); // mp3File yolunu doğru belirtiğinizden emin olun
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  // Bu fonksiyonu doğru veya yanlış eşleşme olduğunda çağırabilirsiniz
  void handleCorrectMatch() {
    playMp3('sounds/correct.mp3'); // 'correct_sound' mp3 dosyasını çalacak
  }

  void handleWrongMatch() {
    playMp3('sounds/wrong.mp3'); // 'wrong_sound' mp3 dosyasını çalacak
  }

  void handleCollect() {
    playMp3('sounds/collect.mp3'); // 'wrong_sound' mp3 dosyasını çalacak
  }

  late ConfettiController _confettiController;
  late BannerAd _ad;
  late bool isLoaded;

  List<String> englishWords = [];
  List<String> turkishWords = [];

  String? selectedEnglishWord;
  String? selectedTurkishWord;

  List<MapEntry<String, String>> matchedPairs = [];
  List<MapEntry<String, String>> wrongPairs = [];

  double wrongMatchScale = 1.0; // Yanlış eşleşme için ölçek

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));

    isLoaded = false;

    _ad = BannerAd(
      size: AdSize.banner,
      adUnitId: AdHelper.bannerAdUnitId,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            isLoaded = true;
          });
        },
        onAdFailedToLoad: (_, error) {
          print("Ad Failed to Load with Error= $error");
        },
      ),
      request: AdRequest(),
    );
    _ad.load();

    selectRandomPairs();
  }

  Widget checkForAd() {
    if (isLoaded == true) {
      return Container(
        child: AdWidget(
          ad: _ad,
        ),
        width: _ad.size.width.toDouble(),
        alignment: Alignment.center,
      );
    } else {
      return CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white), // Beyaz renk
      );
    }
  }

  void selectRandomPairs() {
    final random = Random();
    List<MapEntry<String, String>> allPairs = wordPairs.entries.toList();
    allPairs.shuffle(random); // Kelime çiftlerini rastgele sırala

    // Sadece 7 kelime çifti seç
    final selectedPairs = allPairs.take(8).toList();

    englishWords = selectedPairs.map((pair) => pair.key).toList();
    turkishWords = selectedPairs.map((pair) => pair.value).toList();

    turkishWords.shuffle(random);
  }

  Future<void> saveWrongMatch(String english, String turkish) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> wrongMatches =
        prefs.getStringList('wrongMatches') ?? <String>[];

    String newMatch = '$english - $turkish';
    // Eğer yeni eşleşme zaten mevcutsa, ekleme yapma
    if (!wrongMatches.contains(newMatch)) {
      wrongMatches.add(newMatch);
      await prefs.setStringList('wrongMatches', wrongMatches);
    }
  }

  void checkMatch() {
    if (selectedEnglishWord != null && selectedTurkishWord != null) {
      if (wordPairs[selectedEnglishWord!] == selectedTurkishWord) {
        // Doğru eşleşme
        setState(() {
          matchedPairs
              .add(MapEntry(selectedEnglishWord!, selectedTurkishWord!));
          selectedEnglishWord = null;
          selectedTurkishWord = null;
        });

        // Show a snackbar for feedback

        handleCorrectMatch();

        Future.delayed(Duration(seconds: 1), () {
          setState(() {
            if (matchedPairs.length + wrongPairs.length ==
                englishWords.length) {
              _confettiController.play(); // Konfeti efektini başlat
              handleCollect();

              Future.delayed(Duration(seconds: 1), () {
                setState(() {
                  matchedPairs.clear();
                  wrongPairs.clear();
                  selectRandomPairs();
                });
              });
            }
          });
        });
      } else {
        // Yanlış eşleşme
        String correctTurkishWord =
            wordPairs[selectedEnglishWord!]!; // Doğru Türkçe kelimeyi al
        setState(() {
          wrongPairs.add(MapEntry(selectedEnglishWord!, selectedTurkishWord!));
          saveWrongMatch(selectedEnglishWord!,
              correctTurkishWord); // Doğru kelimeyi kaydet
          selectedEnglishWord = null;
          selectedTurkishWord = null;
        });

        handleWrongMatch();

        // Show a snackbar for feedback

        Future.delayed(Duration(seconds: 1), () {
          setState(() {
            selectedEnglishWord = null;
            selectedTurkishWord = null;
            wrongPairs.removeLast();
          });
        });
      }
    }
  }

  bool isMatched(String english, String turkish) {
    return matchedPairs
        .any((pair) => pair.key == english && pair.value == turkish);
  }

  bool isWrongMatch(String english, String turkish) {
    return wrongPairs
        .any((pair) => pair.key == english && pair.value == turkish);
  }

  bool isDisabled(String word) {
    return matchedPairs.any((pair) => pair.key == word || pair.value == word) ||
        wrongPairs.any((pair) => pair.key == word || pair.value == word);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Arka plan görseli
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg-canyon.png'), // Arka plan resmi
              fit: BoxFit.cover, // Görselin ölçeklendirme şekli
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent, // Arka planı şeffaf yapıyoruz
          appBar: AppBar(
            title: Text(
              'Quiz',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white, // Kalın yazı
                  fontSize: 18),
            ),
            backgroundColor: Colors.transparent, // Şeffaf arka plan
            elevation: 0, // Gölge kaldırıldı
            actions: [
              IconButton(
                icon: Icon(
                  Icons.list,
                  size: 30.0, // İkon boyutu
                  color: Colors.white, // İkon rengi beyaz
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WrongMatchesPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              Align(
                alignment: Alignment.center,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                  ], // Konfeti renkleri
                ),
              ),
              SizedBox(height: 64),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  for (var word in englishWords)
                                    AnimatedContainer(
                                      duration: Duration(milliseconds: 200),
                                      transform: Matrix4.identity()
                                        ..scale(isWrongMatch(
                                                word, selectedTurkishWord ?? '')
                                            ? wrongMatchScale
                                            : 1.0),
                                      width: 150,
                                      margin:
                                          EdgeInsets.symmetric(vertical: 4.0),
                                      decoration: BoxDecoration(
                                        color: selectedEnglishWord == word
                                            ? Color(0xFF526DD4)
                                            : matchedPairs.any(
                                                    (pair) => pair.key == word)
                                                ? Color(0xFFB7DA5C)
                                                : wrongPairs.any((pair) =>
                                                        pair.key == word)
                                                    ? Color(0xFFFF0000)
                                                    : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black38,
                                            offset: Offset(0, 4),
                                            blurRadius: 8.0,
                                          ),
                                        ],
                                      ),
                                      child: TextButton(
                                        onPressed: () {
                                          if (!isDisabled(word)) {
                                            setState(() {
                                              selectedEnglishWord = word;
                                            });
                                            checkMatch();
                                            speak(word);
                                          }
                                        },
                                        child: Center(
                                          child: Text(
                                            word,
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  for (var word in turkishWords)
                                    AnimatedContainer(
                                      duration: Duration(milliseconds: 200),
                                      transform: Matrix4.identity()
                                        ..scale(isWrongMatch(
                                                selectedEnglishWord ?? '', word)
                                            ? wrongMatchScale
                                            : 1.0),
                                      width: 150,
                                      margin:
                                          EdgeInsets.symmetric(vertical: 4.0),
                                      decoration: BoxDecoration(
                                        color: selectedTurkishWord == word
                                            ? Color(0xFF526DD4)
                                            : matchedPairs.any((pair) =>
                                                    pair.value == word)
                                                ? Color(0xFFB7DA5C)
                                                : wrongPairs.any((pair) =>
                                                        pair.value == word)
                                                    ? Color(0xFFFF0000)
                                                    : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black38,
                                            offset: Offset(0, 4),
                                            blurRadius: 8.0,
                                          ),
                                        ],
                                      ),
                                      child: TextButton(
                                        onPressed: () {
                                          if (!isDisabled(word)) {
                                            setState(() {
                                              selectedTurkishWord = word;
                                            });
                                            checkMatch();
                                          }
                                        },
                                        child: Center(
                                          child: Text(
                                            word,
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomAppBar(
            color: Colors.transparent, // Şeffaf arka plan
            elevation: 0,
            child: Container(
              height: 60.0,
              child: Center(
                child: checkForAd(), // Reklam burada yer alacak
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _ad.dispose();
    _confettiController.dispose(); // Confetti controller'ı dispose edin
    super.dispose();
  }
}

class WrongMatchesPage extends StatefulWidget {
  @override
  _WrongMatchesPageState createState() => _WrongMatchesPageState();
}

class _WrongMatchesPageState extends State<WrongMatchesPage> {
  late Future<List<String>> _wrongMatchesFuture;
  List<String> _wrongMatches = [];
  List<String> _favoriteWords = [];

  late BannerAd _ad;
  late bool isLoaded;

  @override
  void initState() {
    super.initState();
    _loadWrongMatches();
    _loadFavoriteWords();

    isLoaded = false;

    _ad = BannerAd(
      size: AdSize.banner,
      adUnitId: AdHelper.bannerAdUnitId,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            isLoaded = true;
          });
        },
        onAdFailedToLoad: (_, error) {
          print("Ad Failed to Load with Error= $error");
        },
      ),
      request: AdRequest(),
    );
    _ad.load();
  }

  Future<void> _loadWrongMatches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _wrongMatches = prefs.getStringList('wrongMatches') ?? [];
    });
  }

  Future<void> _removeWrongMatch(String match) async {
    final prefs = await SharedPreferences.getInstance();
    _wrongMatches.remove(match); // Yanlış eşleşmeyi kaldır
    await prefs.setStringList(
        'wrongMatches', _wrongMatches); // Güncellenmiş listeyi kaydet
    setState(() {}); // Liste değişti, durumu güncelle
  }

  // Hafızadan kelimeleri yükleyen fonksiyon
  Future<void> _loadFavoriteWords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _favoriteWords = prefs.getStringList('wrongMatches') ?? [];
    });
  }

  // Kelime eşleştirme oyununa yönlendiren fonksiyon
  void _startQuiz() {
    if (_favoriteWords.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WordMatchingGame(words: _favoriteWords),
        ),
      );
    } else {
      // Eğer kelime yoksa, bir uyarı göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Favori kelimeler bulunamadı.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Arka plan görseli
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image:
                  AssetImage('assets/bg-canyon.png'), // Görsel dosyasının yolu
              fit: BoxFit.cover, // Görselin tam ekran kaplaması için
            ),
          ),
        ),
        Scaffold(
          backgroundColor:
              Colors.transparent, // Scaffold'un arka planını şeffaf yapıyoruz
          appBar: AppBar(
            title: Text(
              'Öğrenilecek Kelimeler',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back, // Geri ikonu
                color: Colors.white, // Beyaz renk
              ),
              onPressed: () {
                Navigator.pop(context); // Geri gitmek için
              },
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.videogame_asset,
                    color: Colors.white), // Quiz ikonu
                onPressed: _startQuiz, // Butona tıklanınca oyunu başlat
              ),
            ],
          ),
          body: Column(
            children: [
              SizedBox(height: 72),
              Expanded(
                child: FutureBuilder<List<String>>(
                  future: getWrongMatches(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white), // Beyaz renk
                        ),
                      );
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Bir hata oluştu'));
                    } else {
                      final wrongMatches = snapshot.data ?? [];
                      return ListView.builder(
                        itemCount: wrongMatches.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: EdgeInsets.symmetric(
                              vertical: 4.0,
                              horizontal: 32.0,
                            ), // Kenar boşluğu
                            decoration: BoxDecoration(
                              color: Colors.white, // Arka plan rengi
                              borderRadius: BorderRadius.circular(
                                  12.0), // Yuvarlatılmış kenarlar
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 2),
                                  blurRadius: 4.0,
                                ),
                              ],
                            ),
                            child: ListTile(
                              title: Text(
                                wrongMatches[index],
                                style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold, // Yazı rengi
                                    fontSize: 14),
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.delete,
                                    color: Color(0xFFFF0000)), // Silme ikonu
                                onPressed: () {
                                  _removeWrongMatch(wrongMatches[index]);
                                },
                              ),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomAppBar(
            color: Colors.transparent, // Alt bar şeffaf olacak
            elevation: 0,
            child: Container(
              height: 60.0,
              child: Center(
                child: checkForAd(), // Reklam burada yer alacak
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget checkForAd() {
    if (isLoaded) {
      return Container(
        child: AdWidget(
          ad: _ad,
        ),
        width: _ad.size.width.toDouble(),
        height: _ad.size.height.toDouble(),
        alignment: Alignment.center,
      );
    } else {
      return CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white), // Beyaz renk
      );
    }
  }

  Future<List<String>> getWrongMatches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('wrongMatches') ?? [];
  }
}

class WordMatchingGame extends StatefulWidget {
  final List<String> words;

  WordMatchingGame({required this.words});

  @override
  _WordMatchingGameState createState() => _WordMatchingGameState();
}

class _WordMatchingGameState extends State<WordMatchingGame> {
  static const platform =
      MethodChannel('com.orionapp.kelimeeslestirme/text_to_speech');

  final FlutterTts flutterTts = FlutterTts();

  Future<void> speak(String text) async {
    try {
      await flutterTts.setLanguage(
          "en-US"); // Dili ayarlayın (Türkçe için "tr-TR" kullanabilirsiniz)
      await flutterTts
          .setPitch(1.0); // Ses tonunu ayarlayın (0.5 - 2.0 arasında)
      await flutterTts.speak(text); // Metni oku
    } catch (e) {
      print("Failed to speak: '${e.toString()}'.");
    }
  }

  Future<void> playMp3(String mp3File) async {
    final AudioPlayer audioPlayer = AudioPlayer();

    try {
      await audioPlayer.play(AssetSource(
          mp3File)); // mp3File yolunu doğru belirtiğinizden emin olun
    } catch (e) {
      print("Error playing audio: $e");
    }
  }

  void handleCollect() {
    playMp3('sounds/collect.mp3'); // 'wrong_sound' mp3 dosyasını çalacak
  }

  late ConfettiController _confettiController;

  // Bu fonksiyonu doğru veya yanlış eşleşme olduğunda çağırabilirsiniz
  void handleCorrectMatch() {
    playMp3('sounds/correct.mp3'); // 'correct_sound' mp3 dosyasını çalacak
  }

  void handleWrongMatch() {
    playMp3('sounds/wrong.mp3'); // 'wrong_sound' mp3 dosyasını çalacak
  }

  List<String> _englishWords = []; // İngilizce kelimeleri tutar
  List<String> _turkishWords = []; // Türkçe kelimeleri tutar
  Map<String, String> _wordPairs = {}; // Eşleşen kelimeleri tutan harita
  String? _selectedEnglishWord; // Seçilen İngilizce kelime
  String? _selectedTurkishWord; // Seçilen Türkçe kelime
  int? _incorrectEnglishIndex; // Yanlış İngilizce kelime indeksini tutar
  int? _incorrectTurkishIndex; // Yanlış Türkçe kelime indeksini tutar
  List<String> _favoriteWords = []; // Favori kelimeleri tutacak değişken

  late BannerAd _ad;
  late bool isLoaded;

  // Doğru eşleşmeleri saklayacak listeler
  List<String> _matchedEnglishWords = [];
  List<String> _matchedTurkishWords = [];

  @override
  void initState() {
    super.initState();
    _loadWords();

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));

    isLoaded = false;

    _ad = BannerAd(
      size: AdSize.banner,
      adUnitId: AdHelper.bannerAdUnitId,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            isLoaded = true;
          });
        },
        onAdFailedToLoad: (_, error) {
          print("Ad Failed to Load with Error= $error");
        },
      ),
      request: AdRequest(),
    );
    _ad.load();
  }

  Future<void> _loadWords() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      List<List<String>> wordPairsList = [];
      _favoriteWords =
          prefs.getStringList('wrongMatches') ?? []; // Favori kelimeleri yükle

      // Kelime çiftlerini `widget.words` listesinden oluştur
      if (widget.words.isEmpty) {
        print("widget.words listesi boş."); // Hata ayıklama için konsola yazdır
      } else {
        for (String pair in widget.words) {
          List<String> split = pair.split(' - ');
          if (split.length == 2) {
            wordPairsList.add([
              split[0].trim(),
              split[1].trim()
            ]); // Kelime çiftlerini listeye ekle
            _wordPairs[split[0].trim()] =
                split[1].trim(); // Kelime çiftini haritaya ekle
          } else {
            print(
                "Geçersiz kelime çifti: $pair"); // Geçersiz çiftleri konsola yazdır
          }
        }
      }

      // Kelime çiftlerini karıştır
      if (wordPairsList.isEmpty) {
        print("wordPairsList boş."); // Hata ayıklama için konsola yazdır
      } else {
        wordPairsList.shuffle();

        // Karıştırılmış çiftleri tekrar ayır
        for (var pair in wordPairsList.sublist(
            0, wordPairsList.length > 8 ? 8 : wordPairsList.length)) {
          _englishWords.add(pair[0]); // İngilizce kelimeleri ekle
          _turkishWords.add(pair[1]); // Türkçe kelimeleri ekle
        }

        // Türkçe kelimeleri ayrıca karıştır
        _turkishWords.shuffle();
      }
    });
  }

  void _checkMatch() {
    if (_selectedEnglishWord != null && _selectedTurkishWord != null) {
      final String? correctTurkishWord = _wordPairs[_selectedEnglishWord!];
      final bool isCorrect = correctTurkishWord == _selectedTurkishWord;

      // Doğru eşleşme ise kelimeleri kaydet
      if (isCorrect) {
        setState(() {
          _matchedEnglishWords.add(_selectedEnglishWord!);
          _matchedTurkishWords.add(_selectedTurkishWord!);
          _selectedEnglishWord = null;
          _selectedTurkishWord = null; // Seçimleri sıfırla
        });

        handleCorrectMatch();

        // Debugging: Eşleşme sonrası durum
        print(
            "Doğru Eşleşmeler: ${_matchedEnglishWords.length} / ${_englishWords.length}");

        // Tüm doğru eşleşmeler tamamlandı mı?
        if (_matchedEnglishWords.length == _englishWords.length) {
          // 2 saniye gecikmeyle oyunu yeniden yükle
          Future.delayed(Duration(seconds: 1), () {
            _confettiController.play(); // Konfeti efektini başlat
            handleCollect();
            _reloadGame();
          });
        }
      } else {
        // Yanlış eşleşme
        setState(() {
          _incorrectEnglishIndex = _englishWords.indexOf(_selectedEnglishWord!);
          _incorrectTurkishIndex = _turkishWords.indexOf(_selectedTurkishWord!);

          // 2 saniye sonra tekrar beyaz yap
          Future.delayed(Duration(seconds: 1), () {
            setState(() {
              _incorrectEnglishIndex = null;
              _incorrectTurkishIndex = null;
            });
          });
        });

        handleWrongMatch();
      }

      // Seçimleri sıfırla
      setState(() {
        _selectedEnglishWord = null;
        _selectedTurkishWord = null;
      });
    }
  }

  void _reloadGame() {
    // Gerekli verileri sıfırlamak için initState'i tekrar çağırabilirsiniz
    setState(() {
      _englishWords.clear();
      _turkishWords.clear();
      _wordPairs.clear();
      _matchedEnglishWords.clear();
      _matchedTurkishWords.clear();
      _loadWords(); // Kelimeleri yeniden yükle
    });
  }

  Widget checkForAd() {
    if (isLoaded == true) {
      return Container(
        child: AdWidget(
          ad: _ad,
        ),
        width: _ad.size.width.toDouble(),
        alignment: Alignment.center,
      );
    } else {
      return CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white), // Beyaz renk
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Arka plan görseli tüm ekranı kaplayacak şekilde
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/bg-canyon.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Scaffold(
          backgroundColor:
              Colors.transparent, // Scaffold arka planı transparan yapılıyor
          body: Column(
            children: [
              AppBar(
                title: Text(
                  'Öğrenilecek Kelimelerle Quiz',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
              Align(
                alignment: Alignment.center,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  colors: const [
                    Colors.green,
                    Colors.blue,
                    Colors.pink,
                    Colors.orange,
                    Colors.purple,
                  ], // Konfeti renkleri
                ),
              ),
              SizedBox(height: 48),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // İngilizce Kelimeler Sütunu
                    Expanded(
                      child: ListView.builder(
                        itemCount: _englishWords.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: _matchedEnglishWords
                                    .contains(_englishWords[index])
                                ? null // Eğer kelime zaten eşleşmişse tıklama işlemini engelle
                                : () {
                                    setState(() {
                                      _selectedEnglishWord =
                                          _englishWords[index];
                                      _checkMatch();
                                      speak(_englishWords[index]);
                                    });
                                  },
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 32.0, vertical: 4),
                              padding: EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 8.0),
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black38,
                                    offset: Offset(0, 4),
                                    blurRadius: 8.0,
                                  ),
                                ],
                                color: _matchedEnglishWords
                                        .contains(_englishWords[index])
                                    ? Color(0xFFB7DA5C) // Doğru eşleşme rengi
                                    : (_incorrectEnglishIndex == index)
                                        ? Color(
                                            0xFFFF0000) // Yanlış eşleşme rengi
                                        : (_selectedEnglishWord ==
                                                _englishWords[index]
                                            ? Color(
                                                0xFF526DD4) // Seçili kelime rengi
                                            : Colors.white),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Center(
                                child: Text(
                                  _englishWords[index],
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Türkçe Kelimeler Sütunu
                    Expanded(
                      child: ListView.builder(
                        itemCount: _turkishWords.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: _matchedTurkishWords
                                    .contains(_turkishWords[index])
                                ? null // Eğer kelime zaten eşleşmişse tıklama işlemini engelle
                                : () {
                                    setState(() {
                                      _selectedTurkishWord =
                                          _turkishWords[index];
                                      _checkMatch();
                                    });
                                  },
                            child: Container(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 32.0, vertical: 4.0),
                              padding: EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 8.0),
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black38,
                                    offset: Offset(0, 4),
                                    blurRadius: 8.0,
                                  ),
                                ],
                                color: _matchedTurkishWords
                                        .contains(_turkishWords[index])
                                    ? Color(0xFFB7DA5C) // Doğru eşleşme rengi
                                    : (_incorrectTurkishIndex == index)
                                        ? Color(
                                            0xFFFF0000) // Yanlış eşleşme rengi
                                        : (_selectedTurkishWord ==
                                                _turkishWords[index]
                                            ? Color(
                                                0xFF526DD4) // Seçili kelime rengi
                                            : Colors.white),
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: Center(
                                child: Text(
                                  _turkishWords[index],
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomAppBar(
            color: Colors
                .transparent, // Alt barın arka planı da transparan yapılacak
            child: Container(
              height: 60.0,
              child: Center(
                child: Container(
                  alignment: Alignment.center,
                  child: checkForAd(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
