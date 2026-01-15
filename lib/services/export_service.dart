import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/gift.dart';
import '../models/guest.dart';
import 'storage_service.dart';

import 'package:permission_handler/permission_handler.dart';

class ImportResult {
  final int insertedGuests;
  final int insertedGifts;
  final List<String> errors;

  ImportResult({
    required this.insertedGuests,
    required this.insertedGifts,
    this.errors = const [],
  });
}

class ExportService {
  final StorageService _storage = StorageService();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  // --- Export Methods ---

  // --- Export Methods ---

  Future<String?> exportToJson() async {
    try {
      final guests = await _storage.getAllGuests();
      final gifts = await _storage.getAllGifts();

      final Map<String, dynamic> data = {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'guests': guests.map((g) => g.toMap()).toList(),
        'gifts': gifts.map((g) => g.toMap()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final fileName = '随礼记_备份_${_dateFormat.format(DateTime.now())}.json';

      return await _saveFile(
        bytes: utf8.encode(jsonString),
        fileName: fileName,
      );
    } catch (e) {
      throw Exception('导出 JSON 失败: $e');
    }
  }

  Future<String?> exportToExcel() async {
    try {
      final guests = await _storage.getAllGuests();
      final gifts = await _storage.getAllGifts();
      
      final Map<int, Guest> guestMap = {for (var g in guests) g.id!: g};

      var excel = Excel.createExcel();
      Sheet sheet = excel['Sheet1'];

      List<String> headers = ['姓名', '关系', '类型', '事由', '金额', '日期', '备注'];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      for (var gift in gifts) {
        final guest = guestMap[gift.guestId];
        final guestName = guest?.name ?? '未知';
        final relationship = guest?.relationship ?? '其他';
        
        List<CellValue> row = [
          TextCellValue(guestName),
          TextCellValue(relationship),
          TextCellValue(gift.isReceived ? '收礼' : '送礼'),
          TextCellValue(gift.eventType),
          DoubleCellValue(gift.amount),
          TextCellValue(_dateFormat.format(gift.date)),
          TextCellValue(gift.note ?? ''),
        ];
        sheet.appendRow(row);
      }
      
      final fileName = '随礼记_数据_${_dateFormat.format(DateTime.now())}.xlsx';
      final fileBytes = excel.encode();

      if (fileBytes != null) {
        return await _saveFile(
          bytes: fileBytes,
          fileName: fileName,
        );
      }
      return null;
    } catch (e) {
      throw Exception('导出 Excel 失败: $e');
    }
  }

  /// 导出待处理清单到Excel
  Future<String?> exportPendingListToExcel({
    required List<Gift> gifts,
    required Map<int, Guest> guestMap,
    required String listType, // '未还' 或 '待收'
  }) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Sheet1'];

      List<String> headers = ['姓名', '关系', '事由', '金额', '日期', '已过天数', '提醒次数'];
      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

      for (var gift in gifts) {
        final guest = guestMap[gift.guestId];
        final guestName = guest?.name ?? '未知';
        final relationship = guest?.relationship ?? '其他';
        final daysPassed = DateTime.now().difference(gift.date).inDays;
        
        List<CellValue> row = [
          TextCellValue(guestName),
          TextCellValue(relationship),
          TextCellValue(gift.eventType),
          DoubleCellValue(gift.amount),
          TextCellValue(_dateFormat.format(gift.date)),
          IntCellValue(daysPassed),
          IntCellValue(gift.remindedCount),
        ];
        sheet.appendRow(row);
      }
      
      final fileName = '随礼记_${listType}清单_${_dateFormat.format(DateTime.now())}.xlsx';
      final fileBytes = excel.encode();

      if (fileBytes != null) {
        return await _saveFile(
          bytes: fileBytes,
          fileName: fileName,
        );
      }
      return null;
    } catch (e) {
      throw Exception('导出待处理清单失败: $e');
    }
  }

  Future<void> shareFile(String path) async {
    final mimeType = path.endsWith('.json') 
        ? 'application/json' 
        : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        
    await Share.shareXFiles(
      [XFile(path, mimeType: mimeType)],
      text: '随礼记数据导出',
    );
  }

  // --- Import Methods ---
  // ... (Import methods remain same, skipping replacement if I can target correctly)
  // I need to be careful with range.
  // I'll replace the Helpers section too to rename _saveAndShareFile to _saveFile. 
  
  // Actually, I can replace the whole file content for safety or use multiple chunks.
  // The 'Import Methods' block is large and unchanged.
  // I will target _saveAndShareFile at the bottom first?
  // Or just replace the Export methods.
  
  // Let's replace Helpers.
  


// ... class ExportService

  Future<String?> _saveFile({
    required List<int> bytes,
    required String fileName,
  }) async {
    // 桌面端使用 FilePicker 保存
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '导出文件',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [fileName.split('.').last],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(bytes);
        return outputFile;
      }
      return null;
    } else if (Platform.isAndroid) {
      // Android 尝试保存到 Download 目录
      try {
        // 请求存储权限 (Android < 11 需要 storage，Android 11+ 可能需要 manageExternalStorage 但 Google Play 限制严格)
        // 这里尝试基础 storage 权限，如果失败则回退到分享
        if (await Permission.storage.request().isGranted || 
            await Permission.manageExternalStorage.request().isGranted) {
          
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            final filePath = '${downloadDir.path}/$fileName';
            await File(filePath).writeAsBytes(bytes);
            return filePath; // 返回公共目录路径
          }
        }
      } catch (e) {
        // 权限或IO错误，回退到临时目录
        debugPrint('Save to Download failed: $e');
      }
    }
    
    // 移动端默认回退：保存到临时目录（随后UI层会触发分享）
    final directory = await getTemporaryDirectory();
    final saveFile = File('${directory.path}/$fileName');
    await saveFile.writeAsBytes(bytes);
    return saveFile.path;
  }

  // --- Import Methods ---

  Future<ImportResult> importFromJson(String filePath) async {
    int newGuests = 0;
    int newGifts = 0;
    List<String> errors = [];

    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(jsonString);

      if (data['guests'] != null) {
        final List guestsList = data['guests'];
        // 创建旧 ID 到新 ID 的映射，因为导入后数据库 ID 会变
        Map<int, int> guestIdMap = {};

        for (var gMap in guestsList) {
          try {
            // 尝试通过姓名查找现有 Guest
            final String name = gMap['name'];
            final existingGuest = await _storage.getGuestByName(name);
            final int oldId = gMap['id']; // 备份文件里的 ID

            if (existingGuest != null) {
              guestIdMap[oldId] = existingGuest.id!;
            } else {
              // 创建新 Guest
              final guest = Guest(
                name: name,
                relationship: gMap['relationship'] ?? '其他',
                phone: gMap['phone'],
                note: gMap['note'],
              );
              final newId = await _storage.insertGuest(guest);
              guestIdMap[oldId] = newId;
              newGuests++;
            }
          } catch (e) {
            errors.add('导入宾客失败: $gMap - $e');
          }
        }

        if (data['gifts'] != null) {
          final List giftsList = data['gifts'];
          for (var gMap in giftsList) {
            try {
              final int oldGuestId = gMap['guestId'];
              final int? targetGuestId = guestIdMap[oldGuestId];

              if (targetGuestId != null) {
                final gift = Gift(
                  guestId: targetGuestId,
                  amount: (gMap['amount'] as num).toDouble(),
                  isReceived: gMap['isReceived'] == 1 || gMap['isReceived'] == true, // 兼容多种格式
                  eventType: gMap['eventType'],
                  date: DateTime.parse(gMap['date']),
                  note: gMap['note'],
                );
                await _storage.insertGift(gift);
                newGifts++;
              } else {
                errors.add('跳过记录: 找不到对应宾客 (Old ID: $oldGuestId)');
              }
            } catch (e) {
              errors.add('导入礼金记录失败: $gMap - $e');
            }
          }
        }
      }
    } catch (e) {
      errors.add('文件解析失败: $e');
      throw Exception('导入失败: $e');
    }

    return ImportResult(insertedGuests: newGuests, insertedGifts: newGifts, errors: errors);
  }

  Future<ImportResult> importFromExcel(String filePath) async {
    int newGuests = 0;
    int newGifts = 0;
    var skippedDuplicates = 0;
    List<String> errors = [];

    try {
      var bytes = File(filePath).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        // 严格校验表头
        if (sheet.rows.isEmpty) {
          throw Exception('表格为空');
        }

        var headerRow = sheet.rows.first;
        Map<String, int> columnIndex = {};
        
        for (int i = 0; i < headerRow.length; i++) {
          final cellValue = _getCellValue(headerRow.elementAtOrNull(i)).trim();
          if (cellValue.isNotEmpty) {
            columnIndex[cellValue] = i;
          }
        }

        // 检查必需列
        final requiredColumns = {'姓名', '金额', '类型'};
        final missingColumns = requiredColumns.where((col) => !columnIndex.containsKey(col)).toList();
        
        if (missingColumns.isNotEmpty) {
          throw Exception('Excel缺少必需列: ${missingColumns.join(", ")}\n必需列为: 姓名、金额、类型');
        }

        final nameIdx = columnIndex['姓名']!;
        final amountIdx = columnIndex['金额']!;
        final typeIdx = columnIndex['类型']!;
        final relationIdx = columnIndex['关系'];
        final eventIdx = columnIndex['事由'];
        final dateIdx = columnIndex['日期'];
        final noteIdx = columnIndex['备注'];

        // 获取现有所有礼金记录用于重复检测
        final existingGifts = await _storage.getAllGifts();
        
        // 处理数据行（跳过表头）
        for (int rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
          var row = sheet.rows[rowIndex];
          if (row.isEmpty) continue;

          try {
            // 解析必需字段
            final nameVal = _getCellValue(row.elementAtOrNull(nameIdx)).trim();
            if (nameVal.isEmpty) {
              errors.add('第${rowIndex + 1}行: 姓名不能为空');
              continue;
            }

            final amountVal = _getDoubleValue(row.elementAtOrNull(amountIdx));
            if (amountVal <= 0) {
              errors.add('第${rowIndex + 1}行: 金额必须大于0');
              continue;
            }

            final typeVal = _getCellValue(row.elementAtOrNull(typeIdx)).trim();
            if (typeVal.isEmpty) {
              errors.add('第${rowIndex + 1}行: 类型不能为空');
              continue;
            }

            // 解析类型
            bool isReceived;
            if (typeVal.contains('收')) {
              isReceived = true;
            } else if (typeVal.contains('送')) {
              isReceived = false;
            } else {
              errors.add('第${rowIndex + 1}行: 类型必须为"收礼"或"送礼"，当前值: $typeVal');
              continue;
            }

            // 解析可选字段
            final relationVal = relationIdx != null 
                ? _getCellValue(row.elementAtOrNull(relationIdx), defaultVal: '其他')
                : '其他';
            final eventVal = eventIdx != null
                ? _getCellValue(row.elementAtOrNull(eventIdx), defaultVal: '其他')
                : '其他';
            final dateVal = dateIdx != null
                ? _getDateValue(row.elementAtOrNull(dateIdx))
                : DateTime.now();
            final noteVal = noteIdx != null
                ? _getCellValue(row.elementAtOrNull(noteIdx))
                : '';

            // 处理 Guest
            int guestId;
            final existingGuest = await _storage.getGuestByName(nameVal);
            if (existingGuest != null) {
              guestId = existingGuest.id!;
            } else {
              final newGuest = Guest(name: nameVal, relationship: relationVal);
              guestId = await _storage.insertGuest(newGuest);
              newGuests++;
            }

            // 重复检测：同一个人、同样金额、同一天、同样类型 = 重复
            final isDuplicate = existingGifts.any((gift) =>
                gift.guestId == guestId &&
                gift.amount == amountVal &&
                gift.isReceived == isReceived &&
                gift.date.year == dateVal.year &&
                gift.date.month == dateVal.month &&
                gift.date.day == dateVal.day);

            if (isDuplicate) {
              skippedDuplicates++;
              errors.add('第${rowIndex + 1}行: 检测到重复数据，已跳过 ($nameVal, ¥$amountVal, ${_dateFormat.format(dateVal)})');
              continue;
            }

            // 插入 Gift
            final gift = Gift(
              guestId: guestId,
              amount: amountVal,
              isReceived: isReceived,
              eventType: eventVal,
              date: dateVal,
              note: noteVal.isNotEmpty ? noteVal : null,
            );
            
            await _storage.insertGift(gift);
            newGifts++;

          } catch (e) {
            errors.add('第${rowIndex + 1}行解析失败: $e');
            continue;
          }
        }
      }
    } catch (e) {
      throw Exception('Excel读取失败: $e');
    }

    return ImportResult(insertedGuests: newGuests, insertedGifts: newGifts, errors: errors);
  }

  // --- Helpers ---



  String _getCellValue(Data? data, {String defaultVal = ''}) {
    if (data == null || data.value == null) return defaultVal;
    final cell = data.value;
    return cell.toString();
  }

  double _getDoubleValue(Data? data) {
    if (data == null || data.value == null) return 0.0;
    final cell = data.value;
    if (cell is DoubleCellValue) return cell.value;
    if (cell is IntCellValue) return cell.value.toDouble();
    if (cell is TextCellValue) return double.tryParse(cell.value.toString()) ?? 0.0;
    return 0.0;
  }
  
  DateTime _getDateValue(Data? data) {
    if (data == null || data.value == null) return DateTime.now();
    final cell = data.value;
    
    if (cell is DateCellValue) {
      return DateTime(cell.year, cell.month, cell.day, 0, 0);
    }
    if (cell is TextCellValue) {
       try {
         return DateTime.parse(cell.value.toString());
       } catch(_) {
         return DateTime.now();
       }
    }
    return DateTime.now();
  }
}

extension ListGetOrNull<T> on List<T> {
  T? elementAtOrNull(int index) {
    if (index >= 0 && index < length) return this[index];
    return null;
  }
}
