import 'package:geolocator/geolocator.dart';
import 'dart:convert' as dart_convert; 
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:http/http.dart' as http; 
import 'package:universal_html/html.dart' as html; 
import 'package:toastification/toastification.dart'; 

// --- 五花馬智能點餐系統 v19.6 動態即時天氣 + Cookie 通知整合版 ---
void main() => runApp(const WuhuamaApp());

class WuhuamaApp extends StatelessWidget {
  const WuhuamaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: MaterialApp(
        title: '五花馬智能點餐系統',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.red,
          useMaterial3: true,
          fontFamily: 'sans-serif',
          cardTheme: const CardThemeData(
            elevation: 5,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(15)),
            ),
          ),
        ),
        home: const OrderScreen(),
      ),
    );
  }
}

class Dish {
  final String name;
  final String imagePath;
  final bool isBeef, isSoup, isNoodle, isVeg, isDumpling;
  final String category;
  final int price;
  final String portion;
  int stock; 

  Dish({
    required this.name,
    required this.imagePath,
    required this.category,
    this.isBeef = false,
    this.isSoup = false,
    this.isNoodle = false,
    this.isVeg = false,
    this.isDumpling = false,
    this.price = 70,
    this.stock = 50, 
    this.portion = '',
  });
}

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  bool _hasProcessed = false;
  String _userText = "（等待語音輸入...）";
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = "點擊下方麥克風，告訴我想吃什麼...";
  
  // 天氣狀態變數
  double? _currentTemp; 
  bool _isLoadingWeather = false;

  List<Dish> _recommendedList = []; 
  final Map<Dish, int> _cart = {}; 

  final List<Dish> _menu = [
    Dish(name: "高麗菜水餃", imagePath: "assets/p1.avif", isDumpling: true, category: 'p', price: 70, portion: "10顆"),
    Dish(name: "韭菜水餃", imagePath: "assets/p2.avif", isDumpling: true, category: 'p', price: 70, portion: "10顆"),
    Dish(name: "地瓜葉水餃", imagePath: "assets/p3.avif", isDumpling: true, category: 'p', price: 75, portion: "10顆"),
    Dish(name: "玉米水餃", imagePath: "assets/p4.avif", isDumpling: true, category: 'p', price: 75, portion: "10顆"),
    Dish(name: "南瓜水餃", imagePath: "assets/p5.avif", isDumpling: true, category: 'p', price: 80, portion: "10顆"),
    Dish(name: "虱目魚水餃", imagePath: "assets/p6.avif", isDumpling: true, category: 'p', price: 90, portion: "10顆"),
    Dish(name: "蝦仁水餃", imagePath: "assets/p7.avif", isDumpling: true, category: 'p', price: 95, portion: "10顆"),
    Dish(name: "酸辣湯餃", imagePath: "assets/p8.avif", isDumpling: true, isSoup: true, category: 'p', price: 95, portion: "8顆"),
    Dish(name: "牛肉湯餃", imagePath: "assets/p9.avif", isDumpling: true, isSoup: true, isBeef: true, category: 'p', price: 125, portion: "8顆"),
    Dish(name: "黃金地瓜餡餅", imagePath: "assets/f1.avif", category: 'f', price: 45, portion: "1份"),
    Dish(name: "鍋貼", imagePath: "assets/f2.avif", category: 'f', price: 65, portion: "8顆"),
    Dish(name: "韭菜盒子", imagePath: "assets/f3.avif", category: 'f', price: 50, portion: "1個"),
    Dish(name: "蔥油餅", imagePath: "assets/f4.avif", category: 'f', price: 55, portion: "1份"),
    Dish(name: "港式蘿蔔糕", imagePath: "assets/f5.avif", category: 'f', price: 60,portion: "3塊"),
    Dish(name: "蔥花蛋捲餅", imagePath: "assets/f6.avif", category: 'f', price: 65, portion: "1份"),
    Dish(name: "豬肉餡餅", imagePath: "assets/f7.avif", category: 'f', price: 50, portion: "1個"),
    Dish(name: "牛肉捲餅", imagePath: "assets/f8.avif", isBeef: true, category: 'f', price: 125, portion: "1份"),
    Dish(name: "港式鳳爪", imagePath: "assets/f9.avif", category: 'f', price: 85, portion: "1份"),
    Dish(name: "蟹黃燒賣", imagePath: "assets/f10.avif", category: 'f', price: 95, portion: "6顆"),
    Dish(name: "蝦仁燒賣", imagePath: "assets/f11.avif", category: 'f', price: 105, portion: "6顆"),
    Dish(name: "小籠湯包", imagePath: "assets/f12.avif", isSoup: true, category: 'f', price: 110, portion: "8顆"),
    Dish(name: "韭黃鮮肉煎餃", imagePath: "assets/f13.avif", category: 'f', price: 85, portion: "8顆"),
    Dish(name: "翡翠雞蛋蒸餃", imagePath: "assets/f14.avif", category: 'f', price: 85, portion: "8顆"),
    Dish(name: "招牌乾麵", imagePath: "assets/q1.avif", isNoodle: true, category: 'q', price: 65, portion: "1碗"),
    Dish(name: "招牌湯麵", imagePath: "assets/q2.avif", isNoodle: true, isSoup: true, category: 'q', price: 75, portion: "1碗"),
    Dish(name: "榨菜肉絲麵", imagePath: "assets/q3.avif", isNoodle: true, isSoup: true, category: 'q', price: 85, portion: "1碗"),
    Dish(name: "黑芝麻麻醬麵", imagePath: "assets/q4.avif", isNoodle: true, isVeg: true, category: 'q', price: 75, portion: "1碗"),
    Dish(name: "川味擔擔麵", imagePath: "assets/q5.avif", isNoodle: true, category: 'q', price: 80, portion: "1碗"),
    Dish(name: "牛肉麵", imagePath: "assets/q6.avif", isNoodle: true, isBeef: true, isSoup: true, category: 'q', price: 175, portion: "1碗"),
    Dish(name: "酸辣湯", imagePath: "assets/w1.avif", isSoup: true, category: 'w', price: 45, portion: "1碗"),
    Dish(name: "香菇貢丸湯", imagePath: "assets/w2.avif", isSoup: true, category: 'w', price: 45, portion: "1碗"),
    Dish(name: "溫州大雲吞湯", imagePath: "assets/w3.avif", isSoup: true, category: 'w', price: 85, portion: "1碗"),
    Dish(name: "藥膳排骨湯", imagePath: "assets/w4.avif", isSoup: true, category: 'w', price: 110, portion: "1碗"),
    Dish(name: "元盎四神豬肚湯", imagePath: "assets/w5.avif", isSoup: true, category: 'w', price: 110, portion: "1碗"), 
    Dish(name: "叉燒炒飯", imagePath: "assets/r1.avif", category: 'r', price: 110, portion: "1盤"),
    Dish(name: "揚州炒飯", imagePath: "assets/r2.avif", category: 'r', price: 120, portion: "1盤"),
  ];

  int chineseToNumber(String text) {
    Map<String, int> numbers = {
      '零': 0, '一': 1, '二': 2, '兩': 2, '三': 3, '四': 4, '五': 5, '六': 6, '七': 7, '八': 8, '九': 9,
    };
    if (text == '十') return 10;
    if (text.contains('十')) {
      List<String> parts = text.split('十');
      int tens = 1; int units = 0;
      if (parts[0].isNotEmpty) tens = numbers[parts[0]] ?? 1;
      if (parts.length > 1 && parts[1].isNotEmpty) units = numbers[parts[1]] ?? 0;
      return tens * 10 + units;
    }
    if (text.contains('百')) {
      List<String> parts = text.split('百');
      int hundreds = numbers[parts[0]] ?? 1;
      return hundreds * 100;
    }
    return numbers[text] ?? 1;
  }

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _fetchRealWeather(); 

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndHandleCookie();
    });
  }

  void _checkAndHandleCookie() {
    String? hasCookie = getCookieOnWeb("user_session_id");

    if (hasCookie != null) {
      debugPrint("【歡迎回來】擷取到舊有的 Cookie 資料: $hasCookie");
      _showFeedbackToast("歡迎回來五花馬！已自動為您載入上次設定。");
    } else {
      _showCookieNotification();
    }
  }

  String? getCookieOnWeb(String key) {
    try {
      if (html.window.navigator.userAgent.contains('Mozilla')) {
        final String allCookies = html.document.cookie ?? "";
        if (allCookies.isEmpty) return null;

        final List<String> cookieList = allCookies.split(';');

        for (var cookie in cookieList) {
          final List<String> parts = cookie.split('=');
          if (parts.length >= 2) {
            final String currentKey = parts[0].trim();
            final String currentValue = parts[1].trim();

            if (currentKey == key) {
              return currentValue; 
            }
          }
        }
      }
    } catch (e) {
      debugPrint("非 Web 環境或 Cookie 讀取失敗: $e");
    }
    return null; 
  }

  void setCookieOnWeb(String key, String value, {int days = 7}) {
    try {
      if (html.window.navigator.userAgent.contains('Mozilla')) {
        final date = DateTime.now().add(Duration(days: days));
        final expires = "expires=${date.toUtc().toString()}";
        html.document.cookie = "$key=$value; $expires; path=/; SameSite=Lax; Secure";
        debugPrint("【Cookie 寫入成功】$key=$value");
      }
    } catch (e) {
      debugPrint("非 Web 環境或 Cookie 寫入失敗: $e");
    }
  }

  void _showFeedbackToast(String message) {
    toastification.show(
      context: context,
      title: Text(message),
      autoCloseDuration: const Duration(seconds: 4),
      alignment: Alignment.topRight,
      style: ToastificationStyle.minimal,
      type: ToastificationType.success,
    );
  }

  void _showCookieNotification() {
    toastification.showCustom(
      context: context,
      alignment: Alignment.topRight,
      autoCloseDuration: null,
      builder: (context, holder) {
        return Container(
          width: 360,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: Colors.red.shade100, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cookie_rounded, color: Colors.red.shade700, size: 28),
                  const SizedBox(width: 8),
                  const Text(
                    "隱私權與 Cookie 同意",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                "本點餐系統使用 Cookie 來優化您的點餐體驗與個人化天氣推薦。點選同意代表您接受我們的服務條款。",
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      toastification.dismiss(holder);
                    },
                    child: const Text("婉拒", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onPressed: () {
                      setCookieOnWeb("user_session_id", "wuhuama_user_${DateTime.now().millisecondsSinceEpoch}", days: 7);
                      toastification.dismiss(holder);
                      _showFeedbackToast("感謝您的同意！已為您儲存個人設定。");
                    },
                    child: const Text("我同意", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  void _updateWeatherRecommendation(double temp) {
    List<Dish> tempRecommendation = [];

    if (temp >= 28.0) {
      _text = "今日體感炎熱 (${temp.toStringAsFixed(1)}°C)，為您推薦清爽開胃的乾麵與五花馬招牌水餃！";
      tempRecommendation.addAll(_menu.where((d) => d.isNoodle && !d.isSoup)); 
      tempRecommendation.addAll(_menu.where((d) => d.isDumpling && !d.isSoup)); 
      tempRecommendation.addAll(_menu.where((d) => d.category == 'f' && !d.isSoup)); 
    } else if (temp >= 22.0 && temp < 28.0) {
      _text = "今日氣候舒適宜人 (${temp.toStringAsFixed(1)}°C)，推薦您品嚐黃金火候炒飯與手工現做捲餅點心！";
      tempRecommendation.addAll(_menu.where((d) => d.category == 'r')); 
      tempRecommendation.addAll(_menu.where((d) => d.name.contains('捲餅') || d.name.contains('蒸餃') || d.name.contains('鍋貼')));
    } else {
      _text = "今日體感偏涼 (${temp.toStringAsFixed(1)}°C)，來碗熱呼呼的牛肉湯麵或滋補湯品暖暖胃吧！";
      tempRecommendation.addAll(_menu.where((d) => d.isSoup && d.isNoodle)); 
      tempRecommendation.addAll(_menu.where((d) => d.category == 'w')); 
      tempRecommendation.addAll(_menu.where((d) => d.isSoup && d.isDumpling)); 
    }

    setState(() {
      _recommendedList = tempRecommendation.toSet().toList().take(8).toList();
    });
  }

  Future<void> _fetchRealWeather() async {
    if (_isLoadingWeather) return;
    setState(() {
      _isLoadingWeather = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('使用者拒絕了定位權限');
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception('定位權限被永久拒絕，請去系統設定開啟');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low
      );
      
      double lat = position.latitude;
      double lon = position.longitude;

      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = dart_convert.jsonDecode(response.body);
        final double realTemp = data['current_weather']['temperature'];
        
        setState(() {
          _currentTemp = realTemp;
          _isLoadingWeather = false;
        });

        _updateWeatherRecommendation(realTemp);
      } else {
        throw Exception('伺服器拒絕連線，狀態碼: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ 天氣或定位失敗: $e');
      setState(() {
        _isLoadingWeather = false;
      });
      
      _updateWeatherRecommendation(25.5);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('定位天氣失敗: $e'), backgroundColor: Colors.black87),
        );
      }
    }
  }

  int get _totalPrice => _cart.entries.fold(0, (sum, e) => sum + (e.key.price * e.value));
  int get _totalCount => _cart.values.fold(0, (sum, count) => sum + count);

  void _removeFromCart(Dish dish, [int quantity = 1]) {
    if (!_cart.containsKey(dish)) return;
    setState(() {
      if (_cart[dish]! <= quantity) {
        dish.stock += _cart[dish]!;
        _cart.remove(dish);
      } else {
        _cart[dish] = _cart[dish]! - quantity;
        dish.stock += quantity;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已取消 $quantity 份 ${dish.name}'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _addToCart(Dish dish) {
    if (dish.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${dish.name} 已售完'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }

    setState(() {
      _cart[dish] = (_cart[dish] ?? 0) + 1;
      dish.stock--;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已點購 ${dish.name}，剩餘 ${dish.stock} 份'),
        duration: const Duration(milliseconds: 700),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  void _analyzeInput(String input) {
    if (input.isEmpty) return;

    bool isCancelIntent = input.contains('取消') || input.contains('不要') || input.contains('刪除') || input.contains('移除');
    bool isOrderIntent = input.contains('我要') || input.contains('幫我') || input.contains('來') || input.contains('點') || input.contains('要') || input.contains('想要') || input.contains('吃');
    bool isBackToWeatherIntent = input.contains('推薦') || input.contains('天氣') || input.contains('原本') || input.contains('首頁') || input.contains('返回');

    // --- 1. 處理返回天氣推薦/首頁指令 ---
    if (isBackToWeatherIntent) {
      if (_currentTemp != null) {
        _updateWeatherRecommendation(_currentTemp!);
      } else {
        _updateWeatherRecommendation(25.5);
      }
      return;
    }

    // --- 2. 處理取消指令 ---
    if (isCancelIntent) {
      bool hasRemovedAny = false;
      for (var dish in _menu) {
        if (input.contains(dish.name)) {
          int quantity = 1; 

          RegExp reg = RegExp(r'(\d+|[零一二兩三四五六七八九十百]+)');
          Match? match = reg.firstMatch(input);
          if (match != null) {
            String quantityText = match.group(1)!;
            if (RegExp(r'\d+').hasMatch(quantityText)) {
              quantity = int.parse(quantityText);
            } else {
              quantity = chineseToNumber(quantityText);
            }
          }

          _removeFromCart(dish, quantity);
          hasRemovedAny = true;
        }
      }

      if (hasRemovedAny) {
        setState(() { _text = "已為您處理取消指令：$input"; });
      } else {
        setState(() { _text = "你想取消什麼呢？請說「取消高麗菜水餃」"; });
      }
      return; 
    }

    // --- 3. 檢查是否有餐點名稱但缺少動詞 ---
    bool hasDishName = _menu.any((dish) => input.contains(dish.name));
    if (hasDishName && !isOrderIntent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('有聽到餐點，但請說「我要 / 幫我 / 來一份」或「取消」會更準確'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      setState(() { _text = "請重新說明，例如：我要酸辣湯 或 取消酸辣湯"; });
      return;
    }

    // --- 4. 處理加入購物車邏輯 ---
    bool hasOrderedSomething = false;
    for (var dish in _menu) {
      RegExp reg = RegExp(r'(\d+|[零一二兩三四五六七八九十百]+)\s*(份|碗|個|盤|塊|顆)?\s*' + dish.name);
      Match? match = reg.firstMatch(input);

      if (match != null) {
        String quantityText = match.group(1)!;
        int quantity = 1;

        if (RegExp(r'\d+').hasMatch(quantityText)) {
          quantity = int.parse(quantityText);
        } else {
          quantity = chineseToNumber(quantityText);
        }

        if (quantity > dish.stock) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${dish.name} 庫存不足，目前只剩 ${dish.stock} 份'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
          quantity = dish.stock;
        }

        for (int i = 0; i < quantity; i++) {
          _addToCart(dish);
        }
        hasOrderedSomething = true;
      } else if (input.contains(dish.name) && !input.contains(RegExp(r'(\d+|[零一二兩三四五六七八九十百]+)'))) {
        _addToCart(dish); 
        hasOrderedSomething = true;
      }
    }

    // --- 5. 處理大分類切換 ---
    List<Dish> dumplings = _menu.where((d) => d.isDumpling || d.name.contains('水餃')).toList();
    List<Dish> friedRice = _menu.where((d) => d.category == 'r' || d.name.contains('炒飯')).toList();
    List<Dish> soups = _menu.where((d) => d.isSoup || d.name.contains('湯')).toList();
    List<Dish> noodles = _menu.where((d) => d.isNoodle || d.name.contains('麵')).toList();
    List<Dish> pancakes = _menu.where((d) => d.category == 'f' || d.name.contains('餅')).toList();

    List<List<Dish>> activeCategories = [];
    if (input.contains('水餃')) activeCategories.add(dumplings);
    if (input.contains('炒飯')) activeCategories.add(friedRice);
    if (input.contains('湯')) activeCategories.add(soups);
    if (input.contains('麵')) activeCategories.add(noodles);
    if (input.contains('餅')) activeCategories.add(pancakes);

    setState(() {
      if (activeCategories.isNotEmpty) {
        List<Dish> finalDisplay = [];
        int countPerCategory = (8 / activeCategories.length).floor();
        for (var categoryList in activeCategories) {
          finalDisplay.addAll(categoryList.take(countPerCategory));
        }
        if (finalDisplay.length < 8) {
          int deficit = 8 - finalDisplay.length;
          finalDisplay.addAll(activeCategories[0].where((d) => !finalDisplay.contains(d)).take(deficit));
        }
        
        _recommendedList = finalDisplay.take(8).toList();
        _text = "已為您切換至對應的餐點類別！";
      } else {
        if (hasOrderedSomething) {
          _text = "已幫您加入購物車！您可以繼續點餐，或對我說「回天氣推薦」來查看原本的推薦喔！";
        } else {
          if (input.length > 1) {
            _text = "找不到與「$input」相關的分類，試著說「我要吃水餃」或「回天氣推薦」！";
          }
        }
      }
    });
  }

  void _listen() async {
    if (!_isListening) {
      _hasProcessed = false;
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) {
            setState(() {
              _userText = val.recognizedWords;
              if (val.finalResult && !_hasProcessed) {
                _hasProcessed = true;
                _analyzeInput(_userText);
                _isListening = false;
                _speech.stop();
              }
            });
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _handleCheckout() {
    if (_cart.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("您的訂單內容", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(),
              ..._cart.entries.map((e) => ListTile(
                title: Text(e.key.name),
                trailing: Text("x ${e.value} (\$${e.key.price * e.value})"),
              )),
              const Divider(thickness: 2),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("應付金額：", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("\$$_totalPrice", style: const TextStyle(fontSize: 22, color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("繼續點餐")),
          FilledButton(
            onPressed: () {
              setState(() { 
                _cart.clear(); 
                if (_currentTemp != null) {
                  _updateWeatherRecommendation(_currentTemp!);
                } else {
                  _text = "點擊下方麥克風，告訴我想吃什麼...";
                  _recommendedList = [];
                }
              });
              Navigator.pop(context);
            },
            child: const Text("確認送出"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0.5,
        leadingWidth: 170,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: InkWell(
              onTap: _fetchRealWeather,
              child: Text(
                _isLoadingWeather 
                    ? '天氣更新中...' 
                    : (_currentTemp != null ? '目前氣溫 ${_currentTemp!.toStringAsFixed(1)}°C' : '未取得天氣'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _cart.clear();
                _userText = "（等待語音輸入...）";
                if (_currentTemp != null) _updateWeatherRecommendation(_currentTemp!);
              });
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.red, size: 28)
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 對話區域：店員提示與顧客輸入
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
                color: Colors.white,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '五花馬智能點餐系統',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _text,
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      width: 320,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(15),
                          bottomLeft: Radius.circular(15),
                          bottomRight: Radius.circular(15),
                        ),
                        border: Border.all(color: Colors.red.shade100, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('顧客您說', style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              Icon(Icons.account_circle, color: Colors.red.shade700, size: 16),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _userText,
                            style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.right,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // 菜單 Grid 區塊
              Expanded(
                child: _recommendedList.isEmpty
                    ? const Center(
                        child: Text(
                          "今天想吃點什麼？\n可以試著說說關鍵字喔！\n或是對我說「取消高麗菜水餃」", 
                          textAlign: TextAlign.center, 
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 130),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4, 
                          childAspectRatio: 0.8, 
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        itemCount: _recommendedList.length,
                        itemBuilder: (context, index) {
                          final dish = _recommendedList[index];
                          final count = _cart[dish] ?? 0;
                          return GestureDetector(
                            onTap: () => _addToCart(dish),
                            child: Badge(
                              label: Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                              isLabelVisible: count > 0,
                              backgroundColor: Colors.red,
                              largeSize: 26,
                              child: Card(
                                elevation: 5,
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        color: Colors.white,
                                        width: double.infinity,
                                        child: AvifImage.asset(
                                          dish.imagePath, 
                                          fit: BoxFit.cover, 
                                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                      child: Column(
                                        children: [
                                          Text(
                                            dish.name, 
                                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold), 
                                            maxLines: 1, 
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            "\$${dish.price}", 
                                            style: const TextStyle(fontSize: 17, color: Colors.red, fontWeight: FontWeight.w900),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            dish.portion,
                                            style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "剩餘 ${dish.stock} 份",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: dish.stock <= 10 ? Colors.red : Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),

          // 底部購物車浮動條 (若購物車有東西則顯示)
          if (_cart.isNotEmpty)
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Card(
                color: Colors.red.shade700,
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shopping_cart, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Text(
                            "已點 $_totalCount 份餐點",
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            "小計 \$$_totalPrice",
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.red.shade700,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: _handleCheckout,
                            child: const Text("前往結帳", style: TextStyle(fontWeight: FontWeight.bold)),
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

      // 語音輸入按鈕 (懸浮於右下角)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AvatarGlow(
        animate: _isListening,
        glowColor: Colors.red,
        duration: const Duration(milliseconds: 2000),
        repeat: true,
        child: FloatingActionButton.large(
          onPressed: _listen,
          backgroundColor: _isListening ? Colors.red.shade700 : Colors.red,
          child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white, size: 36),
        ),
      ),
    );
  }
}