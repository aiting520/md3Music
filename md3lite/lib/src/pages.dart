import 'package:flutter/material.dart';

import 'glass.dart';

/// 首页 / 发现 / 资料库 / 设置 —— 精简版，只保留能看清结构的部分。
class SimplePages {
  static Widget home(Color accent) => _scroll([
        _title('深夜场'),
        _grid(accent, const [
          ('透明剧场', '富江 · 3 首'),
          ('过曝的夏天', '单曲循环'),
          ('午夜摆渡', '环境音乐'),
          ('液态', '玻璃声场'),
        ]),
        _title('最近播放'),
        _row('1', '液态玻璃', '富江 · 透明剧场', '1:24'),
        _row('2', '过曝的夏天', '富江 · 透明剧场', '1:12'),
        _row('3', '午夜摆渡', '富江 · 透明剧场', '1:18'),
      ]);

  static Widget find(Color accent) => _scroll([
        _title('为你生成'),
        _hint('根据近 7 天的收听情绪推断'),
        _grid(accent, const [
          ('凌晨三点', '低保真 · 32 首'),
          ('玻璃与雨', '氛围 · 41 首'),
        ]),
        _title('排行榜'),
        _row('01', '液态玻璃', '↑ 3', '+128%'),
        _row('02', '午夜摆渡', '—', '+41%'),
        _row('03', '过曝的夏天', '↓ 1', '+9%'),
      ]);

  static Widget library(Color accent) => _scroll([
        _title('我的'),
        _row('♡', '我喜欢的音乐', '128 首', ''),
        _row('↓', '已下载', '36 首 · 312 MB', ''),
        _title('歌单'),
        _row('1', '透明剧场', '富江 · 3 首', '›'),
        _row('2', '写歌用的草稿', '17 首', '›'),
      ]);

  static Widget settings(Color accent) => _scroll([
        _title('外观'),
        _switchRow('液态玻璃', true),
        _switchRow('歌词流光', true),
        _switchRow('逐字高亮', true),
        _switchRow('弹簧滚动', true),
        _title('关于'),
        _hint('md3lite · 液态玻璃 + Folia 歌词\nFlutter 重写版 · 单包 < 20 MB'),
      ]);

  static Widget _scroll(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
        children: children,
      );

  static Widget _title(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
        child: Text(t,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
      );

  static Widget _hint(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(t,
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.42))),
      );

  static Widget _grid(Color accent, List<(String, String)> items) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.12,
        children: items
            .map((e) => ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accent.withOpacity(0.55),
                              accent.withOpacity(0.18),
                              const Color(0xFF0B1020),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.$1,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                            const SizedBox(height: 3),
                            Text(e.$2,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.white.withOpacity(0.62))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      );

  static Widget _row(String n, String title, String sub, String tail) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: LiquidGlass(
          radius: 16,
          blur: 16,
          tint: 0.07,
          sheen: false,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(n,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.40))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: TextStyle(
                            fontSize: 11.5, color: Colors.white.withOpacity(0.48))),
                  ],
                ),
              ),
              Text(tail,
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.40))),
            ],
          ),
        ),
      );

  static Widget _switchRow(String label, bool value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: LiquidGlass(
          radius: 16,
          blur: 16,
          tint: 0.07,
          sheen: false,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 13.5, color: Colors.white)),
              Switch(value: value, onChanged: (_) {}),
            ],
          ),
        ),
      );
}
