import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '计算器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const CalculatorScreen(),
    );
  }
}

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _input = '0';
  String _result = '';
  String _expression = '';
  bool _showExpression = false;
  bool _isOperatorClicked = false;
  bool _isEqualClicked = false;

  // 添加点击检测相关变量
  DateTime? _lastTapTime;
  Offset? _lastTapPosition;
  static const double _tapAreaSize = 100.0; // 左上角点击区域大小

  void _onDigitPress(String digit) {
    setState(() {
      if (_isEqualClicked) {
        _input = digit;
        _expression = '';
        _showExpression = false;
        _isEqualClicked = false;
      } else if (_input == '0' || _isOperatorClicked) {
        _input = digit;
        _isOperatorClicked = false;
      } else {
        _input += digit;
      }
    });
  }

  void _onOperatorPress(String operator) {
    setState(() {
      if (_isEqualClicked) {
        _expression = _formatNumber(_result);
        _showExpression = true;
        _isEqualClicked = false;
      } else if (_isOperatorClicked) {
        // 替换上一个运算符
        _expression =
            _expression.substring(0, _expression.length - 1) + operator;
        return;
      } else if (_expression.isEmpty) {
        _expression = _input;
      } else {
        // 不再自动计算结果，而是直接将当前输入添加到表达式中
        _expression += _input;
      }

      // 添加操作符
      _expression += operator;
      _isOperatorClicked = true;
      _showExpression = true;
    });
  }

  void _onEqualPress() {
    if (_expression.isEmpty || _isEqualClicked) return;

    setState(() {
      if (!_isOperatorClicked) {
        // 在计算前，确保将当前输入的数字添加到表达式中
        // 检查表达式是否已经包含当前输入，避免重复添加
        if (!_expression.endsWith(_input)) {
          _expression += _input;
        }
        _calculate();
      } else {
        // 如果最后点击的是运算符，则移除它
        _expression = _expression.substring(0, _expression.length - 1);
        _calculate();
      }

      _isEqualClicked = true;
      _isOperatorClicked = false;
      _showExpression = true;
    });
  }

  void _onClearPress() {
    setState(() {
      _input = '0';
      _result = '';
      _expression = '';
      _showExpression = false;
      _isOperatorClicked = false;
      _isEqualClicked = false;
    });
  }

  void _onToggleSignPress() {
    setState(() {
      if (_input != '0') {
        if (_input.startsWith('-')) {
          _input = _input.substring(1);
        } else {
          _input = '-$_input';
        }
      }
    });
  }

  void _onPercentPress() {
    setState(() {
      double value = double.parse(_input) / 100;
      _input = _formatNumber(value.toString());
    });
  }

  void _onDecimalPress() {
    setState(() {
      if (_isEqualClicked) {
        _input = '0.';
        _expression = '';
        _showExpression = false;
        _isEqualClicked = false;
      } else if (_isOperatorClicked) {
        _input = '0.';
        _isOperatorClicked = false;
      } else if (!_input.contains('.')) {
        _input += '.';
      }
    });
  }

  void _calculate() {
    String finalExpression = _expression;
    // 检查表达式是否已经包含当前输入，避免重复添加
    if (!_isOperatorClicked && !_expression.endsWith(_input)) {
      finalExpression += _input;
    }

    // 替换乘除符号为可计算的符号
    finalExpression = finalExpression.replaceAll('×', '*').replaceAll('÷', '/');

    try {
      // 使用简单的方法计算表达式
      _result = _evaluateExpression(finalExpression).toString();
      _input = _formatNumber(_result);
    } catch (e) {
      _input = 'Error';
      _result = '0';
    }
  }

  double _evaluateExpression(String expression) {
    // 检查表达式是否为空
    if (expression.isEmpty) {
      return 0;
    }

    // 处理表达式中的负数
    expression = _preprocessNegativeNumbers(expression);

    // 分词
    List<String> tokens = _tokenizeExpression(expression);

    // 先计算乘除
    List<String> secondPass = _calculateMultiplicationDivision(tokens);

    // 再计算加减
    double result = _calculateAdditionSubtraction(secondPass);

    return result;
  }

  // 预处理负数
  String _preprocessNegativeNumbers(String expression) {
    // 处理表达式开头的负号
    if (expression.startsWith('-')) {
      expression = '0' + expression;
    }

    // 处理运算符后的负号 (如 5*-3)
    expression = expression.replaceAllMapped(
      RegExp(r'([+\-*/])\s*-'),
      (match) => '${match.group(1)}(0-',
    );

    // 为了简化处理，我们在这些位置添加右括号
    int openBrackets = expression.split('(').length - 1;
    int closeBrackets = expression.split(')').length - 1;
    if (openBrackets > closeBrackets) {
      expression += ')' * (openBrackets - closeBrackets);
    }

    return expression;
  }

  // 将表达式分解为标记
  List<String> _tokenizeExpression(String expression) {
    List<String> tokens = [];
    String currentNumber = '';
    bool inBracket = false;
    String bracketContent = '';

    // 调试输出
    print('Tokenizing expression: $expression');

    for (int i = 0; i < expression.length; i++) {
      String char = expression[i];

      // 处理括号
      if (char == '(') {
        if (inBracket) {
          bracketContent += char;
        } else {
          if (currentNumber.isNotEmpty) {
            tokens.add(currentNumber);
            currentNumber = '';
          }
          inBracket = true;
        }
        continue;
      } else if (char == ')') {
        if (inBracket) {
          // 递归计算括号内的表达式
          double bracketResult = _evaluateExpression(bracketContent);
          tokens.add(bracketResult.toString());
          bracketContent = '';
          inBracket = false;
        }
        continue;
      }

      if (inBracket) {
        bracketContent += char;
        continue;
      }

      // 处理运算符和数字
      if (char == '+' || char == '-' || char == '*' || char == '/') {
        if (currentNumber.isNotEmpty) {
          tokens.add(currentNumber);
          currentNumber = '';
        }
        tokens.add(char);
      } else {
        currentNumber += char;
      }
    }

    // 确保最后的数字被添加到tokens中
    if (currentNumber.isNotEmpty) {
      tokens.add(currentNumber);
    }

    // 调试输出最终的tokens
    print('Final tokens: $tokens');

    return tokens;
  }

  // 计算乘法和除法
  List<String> _calculateMultiplicationDivision(List<String> tokens) {
    List<String> result = [];
    int i = 0;

    while (i < tokens.length) {
      if (i + 2 < tokens.length &&
          (tokens[i + 1] == '*' || tokens[i + 1] == '/')) {
        try {
          double left = double.parse(tokens[i]);
          String op = tokens[i + 1];
          double right = double.parse(tokens[i + 2]);
          double opResult;

          if (op == '*') {
            opResult = left * right;
          } else {
            // 检查除数是否为零
            if (right == 0) {
              throw Exception("除数不能为零");
            }
            opResult = left / right;
          }

          // 替换这三个标记为计算结果
          tokens[i] = opResult.toString();
          tokens.removeAt(i + 1); // 移除运算符
          tokens.removeAt(i + 1); // 移除右操作数

          // 不增加i，因为我们需要检查当前结果是否还需要参与乘除运算
        } catch (e) {
          // 如果解析失败，跳过这个操作
          result.add(tokens[i]);
          i++;
        }
      } else {
        result.add(tokens[i]);
        i++;
      }
    }

    return result;
  }

  // 计算加法和减法
  double _calculateAdditionSubtraction(List<String> tokens) {
    if (tokens.isEmpty) {
      return 0;
    }

    // 调试输出
    print('Calculating addition/subtraction for tokens: $tokens');

    try {
      // 确保第一个元素是数字
      if (tokens.length == 1) {
        return double.parse(tokens[0]);
      }

      // 确保使用double类型进行计算，避免字符串连接
      double result = double.tryParse(tokens[0]) ?? 0.0;
      print('Initial value: $result');

      // 逐个处理操作符和操作数
      for (int i = 1; i < tokens.length; i += 2) {
        if (i + 1 < tokens.length) {
          String op = tokens[i];
          // 使用tryParse确保转换为数字，避免格式错误
          double right = double.tryParse(tokens[i + 1]) ?? 0.0;

          if (op == '+') {
            print('Adding $right to $result');
            // 使用明确的数值加法
            double newResult = result + right;
            print('Result after addition: $newResult (from $result + $right)');
            result = newResult;
          } else if (op == '-') {
            print('Subtracting $right from $result');
            // 使用明确的数值减法
            double newResult = result - right;
            print(
              'Result after subtraction: $newResult (from $result - $right)',
            );
            result = newResult;
          }
        }
      }

      print('Final result: $result');
      return result;
    } catch (e) {
      // 如果解析失败，返回0并输出错误信息
      print('Error in calculation: $e');
      return 0;
    }
  }

  String _formatNumber(String number) {
    // 格式化数字，去除不必要的小数点和零
    if (number.contains('.')) {
      number = number.replaceAll(RegExp(r'\.0+$'), '');
      number = number.replaceAll(RegExp(r'(\.[0-9]*[1-9])0+$'), r'$1');
    }

    // 添加千位分隔符
    List<String> parts = number.split('.');
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    parts[0] = parts[0].replaceAllMapped(reg, (Match m) => '${m[1]},');

    return parts.length > 1 ? '${parts[0]}.${parts[1]}' : parts[0];
  }

  // 处理显示区域点击事件的方法
  void _handleDisplayTap(TapDownDetails details) {
    // 添加调试输出，确认方法被调用
    print('_handleDisplayTap 被调用: ${details.localPosition}');

    // 获取当前时间
    DateTime now = DateTime.now();

    // 检查是否在左上角区域内点击
    if (details.localPosition.dx < _tapAreaSize &&
        details.localPosition.dy < _tapAreaSize) {
      print('点击在左上角区域内');
      // 检查是否是双击（两次点击间隔小于500毫秒）
      if (_lastTapTime != null &&
          now.difference(_lastTapTime!).inMilliseconds < 500 &&
          _lastTapPosition != null &&
          (_lastTapPosition!.dx < _tapAreaSize &&
              _lastTapPosition!.dy < _tapAreaSize)) {
        print('检测到双击，执行特殊功能');
        // 执行特殊功能：替换最后一个数值，但不立即计算结果
        _replaceLastNumberWithTimeValue();

        // 重置点击状态，防止连续触发
        _lastTapTime = null;
        _lastTapPosition = null;
        return;
      }
    }

    // 更新最后点击时间和位置
    _lastTapTime = now;
    _lastTapPosition = details.localPosition;

    // 添加额外的调试输出，确认方法执行完成
    print('_handleDisplayTap 执行完成');
  }

  // 替换最后一个数值，使表达式结果等于当前时间戳
  void _replaceLastNumberWithTimeValue() {
    // 如果表达式为空，不执行操作
    if (_expression.isEmpty && _input == '0') return;

    setState(() {
      try {
        // 获取当前时间格式化为年月日时分（如：20253281430）
        DateTime now = DateTime.now();
        String timeValue =
            "${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}";
        double targetResult = double.parse(timeValue);

        // 解析当前表达式，找到最后一个数值
        String workingExpression = _expression;
        if (!_isOperatorClicked) {
          // 如果最后不是操作符，需要添加当前输入到表达式中
          if (!workingExpression.endsWith(_input)) {
            workingExpression += _input;
          }
        } else {
          // 如果最后是运算符，移除它以便计算
          workingExpression = workingExpression.substring(
            0,
            workingExpression.length - 1,
          );
        }

        // 替换乘除符号为可计算的符号
        workingExpression = workingExpression
            .replaceAll('×', '*')
            .replaceAll('÷', '/');

        // 找到最后一个操作符的位置
        int lastOperatorIndex = -1;
        for (int i = workingExpression.length - 1; i >= 0; i--) {
          if (workingExpression[i] == '+' ||
              workingExpression[i] == '-' ||
              workingExpression[i] == '*' ||
              workingExpression[i] == '/') {
            lastOperatorIndex = i;
            break;
          }
        }

        // 提取表达式的前半部分（不包括最后一个数值）
        String expressionPrefix =
            lastOperatorIndex >= 0
                ? workingExpression.substring(0, lastOperatorIndex + 1)
                : "";

        // 计算前半部分表达式的值
        double prefixResult = 0;
        if (expressionPrefix.isNotEmpty) {
          // 为了计算前缀表达式的值，我们临时添加一个0
          prefixResult = _evaluateExpression(expressionPrefix + "0");
        }

        // 根据最后一个操作符计算需要的值
        double requiredValue = targetResult;
        String lastOperator =
            lastOperatorIndex >= 0 ? workingExpression[lastOperatorIndex] : "+";

        switch (lastOperator) {
          case '+':
            requiredValue = targetResult - prefixResult;
            break;
          case '-':
            requiredValue = prefixResult - targetResult;
            break;
          case '*':
            requiredValue = targetResult / prefixResult;
            break;
          case '/':
            requiredValue = prefixResult / targetResult;
            break;
        }

        // 更新表达式和输入，但不立即计算结果
        if (_isOperatorClicked) {
          // 如果最后点击的是操作符，直接在操作符后添加新值
          _expression += requiredValue.toString();
          _isOperatorClicked = false;
        } else if (lastOperatorIndex >= 0) {
          // 有操作符，只替换最后一个数值
          _expression =
              _expression.substring(0, lastOperatorIndex + 1) +
              requiredValue.toString();
        } else {
          // 没有操作符，整个表达式就是一个数值
          _expression = requiredValue.toString();
        }

        // 更新输入显示
        _input = requiredValue.toString();
        _showExpression = true;
      } catch (e) {
        // 出错时显示错误信息并记录日志
        print('Error in _replaceLastNumberWithTimeValue: $e');
        _input = 'Error';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 显示区域
            Expanded(
              child: GestureDetector(
                onTapDown: (TapDownDetails details) {
                  print(
                    'GestureDetector onTapDown 被触发: ${details.localPosition}',
                  );
                  _handleDisplayTap(details);
                },
                onTap: () {
                  print('GestureDetector onTap 被触发');
                  // onTap被触发时，确保显示区域有视觉反馈
                  setState(() {
                    // 可以添加一些视觉反馈，如果需要的话
                  });
                },
                behavior:
                    HitTestBehavior.translucent, // 使用translucent确保能捕获所有点击事件
                child: Container(
                  padding: const EdgeInsets.all(20),
                  alignment: Alignment.bottomRight,
                  color: Colors.transparent, // 添加透明背景色以确保整个区域可点击
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_showExpression)
                        Text(
                          _expression.replaceAll('*', '×').replaceAll('/', '÷'),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 24,
                          ),
                        ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _input,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 60,
                          ),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 按钮区域
            Container(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildButton(
                        _isEqualClicked ? 'AC' : 'AC',
                        Colors.grey,
                        Colors.black,
                      ),
                      _buildButton('+/-', Colors.grey, Colors.black),
                      _buildButton('%', Colors.grey, Colors.black),
                      _buildButton('÷', Colors.orange, Colors.white),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildButton('7', const Color(0xFF505050), Colors.white),
                      _buildButton('8', const Color(0xFF505050), Colors.white),
                      _buildButton('9', const Color(0xFF505050), Colors.white),
                      _buildButton('×', Colors.orange, Colors.white),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildButton('4', const Color(0xFF505050), Colors.white),
                      _buildButton('5', const Color(0xFF505050), Colors.white),
                      _buildButton('6', const Color(0xFF505050), Colors.white),
                      _buildButton('-', Colors.orange, Colors.white),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildButton('1', const Color(0xFF505050), Colors.white),
                      _buildButton('2', const Color(0xFF505050), Colors.white),
                      _buildButton('3', const Color(0xFF505050), Colors.white),
                      _buildButton('+', Colors.orange, Colors.white),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildWideButton(
                        '0',
                        const Color(0xFF505050),
                        Colors.white,
                      ),
                      _buildButton('.', const Color(0xFF505050), Colors.white),
                      _buildButton('=', Colors.orange, Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String text, Color bgColor, Color textColor) {
    double buttonSize = (MediaQuery.of(context).size.width - 50) / 4;

    void Function()? onPressed;

    switch (text) {
      case '0':
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9':
        onPressed = () => _onDigitPress(text);
        break;
      case '+':
      case '-':
      case '×':
      case '÷':
        onPressed = () => _onOperatorPress(text);
        break;
      case '=':
        onPressed = _onEqualPress;
        break;
      case 'AC':
        onPressed = _onClearPress;
        break;
      case '+/-':
        onPressed = _onToggleSignPress;
        break;
      case '%':
        onPressed = _onPercentPress;
        break;
      case '.':
        onPressed = _onDecimalPress;
        break;
    }

    return Container(
      width: buttonSize,
      height: buttonSize,
      margin: const EdgeInsets.all(2),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          backgroundColor: bgColor,
          padding: EdgeInsets.zero,
        ),
        child: Text(text, style: TextStyle(fontSize: 30, color: textColor)),
      ),
    );
  }

  Widget _buildWideButton(String text, Color bgColor, Color textColor) {
    double buttonSize = (MediaQuery.of(context).size.width - 50) / 4;

    return Container(
      width: buttonSize * 2 + 4, // 加上间距
      height: buttonSize,
      margin: const EdgeInsets.all(2),
      child: ElevatedButton(
        onPressed: () => _onDigitPress(text),
        style: ElevatedButton.styleFrom(
          shape: const StadiumBorder(),
          backgroundColor: bgColor,
          padding: EdgeInsets.zero,
        ),
        child: Text(text, style: TextStyle(fontSize: 30, color: textColor)),
      ),
    );
  }
}
