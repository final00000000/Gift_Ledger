import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';

class ExportDialogs {
  static final ExportService _exportService = ExportService();

  static void showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '导出数据',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildOptionTile(
              context,
              icon: Icons.data_object_rounded,
              title: '导出为 JSON (备份)',
              subtitle: '完整备份所有数据，适合迁移设备',
              onTap: () async {
                Navigator.pop(context);
                await _performExport(context, 'JSON', () => _exportService.exportToJson());
              },
            ),
            _buildOptionTile(
              context,
              icon: Icons.table_chart_rounded,
              title: '导出为 Excel',
              subtitle: '生成表格文件，便于在电脑查看编辑',
              onTap: () async {
                Navigator.pop(context);
                await _performExport(context, 'Excel', () => _exportService.exportToExcel());
              },
            ),
            const SizedBox(height: AppTheme.spacingL),
          ],
        ),
      ),
    );
  }

  static void showImportOptions(BuildContext context, VoidCallback? onSuccess) {
    // 保存稳定的scaffold context，在整个导入流程中使用
    final scaffoldContext = context;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '导入数据',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '注意：导入操作会向现有数据库追加数据，不会覆盖现有记录。请避免重复导入相同文件。',
                style: TextStyle(color: AppTheme.warningColor, fontSize: 13),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildOptionTile(
              sheetContext,
              icon: Icons.data_object_rounded,
              title: '从 JSON 恢复',
              subtitle: '恢复之前的备份文件',
              onTap: () async {
                Navigator.pop(sheetContext);
                await _pickAndImport(scaffoldContext, ['json'], onSuccess, isJson: true);
              },
            ),
            _buildOptionTile(
              sheetContext,
              icon: Icons.table_chart_rounded,
              title: '从 Excel 导入',
              subtitle: '导入编辑好的表格数据',
              onTap: () {
                Navigator.pop(sheetContext);
                _showExcelTips(scaffoldContext, onSuccess);
              },
            ),
            const SizedBox(height: AppTheme.spacingL),
          ],
        ),
      ),
    );
  }

  static void _showExcelTips(BuildContext parentContext, VoidCallback? onSuccess) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excel 导入说明'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('请确保 Excel 文件符合以下格式：'),
            SizedBox(height: 8),
            Text('1. 第一行必须是表头'),
            Text('2. 必需列：姓名, 金额, 类型'),
            Text('3. 类型列填写：收礼 或 送礼'),
            Text('4. 其他列：关系, 事由, 日期, 备注'),
            SizedBox(height: 12),
            Text('提示：如果"姓名"已存在，将自动关联；如果不存在，将创建新联系人。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // 使用父级context而不是对话框context
              await _pickAndImport(parentContext, ['xlsx', 'xls'], onSuccess, isJson: false);
            },
            child: const Text('选择文件'),
          ),
        ],
      ),
    );
  }

  static Future<void> _performExport(
      BuildContext context, String type, Future<String?> Function() exportFunc) async {
    
    // 显示加载动画
    _showLoading(context, '正在导出 $type...');
    
    bool loadingDismissed = false;
    void dismissLoading() {
      if (!loadingDismissed && context.mounted) {
        loadingDismissed = true;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    
    try {
      final path = await exportFunc();
      dismissLoading();

      if (path != null && context.mounted) {
        // 如果返回值是提示信息（非路径），直接显示
        final message = path.startsWith('/') || path.startsWith('\\') || path.contains(':') 
            ? '文件已保存: $path' 
            : path;
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      dismissLoading();
      if (context.mounted) {
        _showError(context, '导出失败: $e');
      }
    }
  }

  static Future<void> _pickAndImport(
    BuildContext context, 
    List<String> extensions, 
    VoidCallback? onSuccess,
    {required bool isJson}
  ) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
      );
    } catch (e) {
      if (context.mounted) {
        _showError(context, '选择文件失败: $e');
      }
      return;
    }

    if (result == null || result.files.single.path == null) {
      // 用户取消了选择
      return;
    }

    String path = result.files.single.path!;
    
    _showLoading(context, '正在导入数据...');
    
    bool loadingDismissed = false;
    void dismissLoading() {
      if (!loadingDismissed && context.mounted) {
        loadingDismissed = true;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
    
    try {
      ImportResult importResult;
      if (isJson) {
        importResult = await _exportService.importFromJson(path);
      } else {
        importResult = await _exportService.importFromExcel(path);
      }

      dismissLoading();
      
      if (context.mounted) {
        _showImportResult(context, importResult, onSuccess);
      }
    } catch (e) {
      dismissLoading();
      if (context.mounted) {
        // 显示详细的错误信息
        String errorMsg = e.toString();
        if (errorMsg.contains('Excel')) {
          errorMsg = 'Excel文件格式错误，请检查：\n1. 是否为有效的xlsx/xls文件\n2. 第一行是否包含表头\n3. 是否包含姓名、金额、类型列';
        } else if (errorMsg.contains('JSON') || errorMsg.contains('json')) {
          errorMsg = 'JSON文件格式错误，请确保文件是由本应用导出的备份文件';
        }
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('导入失败'),
            content: Text(errorMsg),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    }
  }
  
  static void _showImportResult(BuildContext context, ImportResult result, VoidCallback? onSuccess) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入完成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('成功导入宾客: ${result.insertedGuests} 位'),
            Text('成功导入礼金: ${result.insertedGifts} 条'),
            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('警告: ${result.errors.length} 条数据导入失败'),
              const SizedBox(height: 4),
              Container(
                height: 100,
                width: double.maxFinite,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    result.errors.join('\n'),
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              onSuccess?.call();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  static void _showLoading(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  static Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
