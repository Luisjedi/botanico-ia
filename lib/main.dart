import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
void main() => runApp(const BotanicoApp());

class BotanicoApp extends StatelessWidget {
  const BotanicoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16865B);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Botânico IA',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: green, brightness: Brightness.light),
        scaffoldBackgroundColor: const Color(0xFFF5F8F4),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF5F8F4), elevation: 0),
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final picker = ImagePicker();
  File? selectedImage;
  bool loading = false;
  Map<String, dynamic>? identification;
  String? error;

  // Endereco publico do Worker Cloudflare do projeto Botânico IA.
  // A chave Pl@ntNet permanece protegida no servidor, nunca neste aplicativo.
  static const apiBaseUrl = 'https://botanico-ia.ybourne40.workers.dev';

  Future<void> chooseImage(ImageSource source) async {
    final image = await picker.pickImage(source: source, imageQuality: 88, maxWidth: 1800);
    if (image == null) return;
    setState(() { selectedImage = File(image.path); identification = null; error = null; });
  }

  Future<void> identifyPlant() async {
    if (selectedImage == null) return;
    if (apiBaseUrl.isEmpty) {
      setState(() => error = 'Configure BOTANICO_API_URL conforme o README para conectar a inteligência artificial.');
      return;
    }
    setState(() { loading = true; error = null; identification = null; });
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$apiBaseUrl/identify'))
        ..files.add(await http.MultipartFile.fromPath('image', selectedImage!.path));
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      final decoded = jsonDecode(response.body);
      final body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // O Worker pode devolver o resultado diretamente ou dentro de
        // { success: true, identification: { results: [...] } }.
        final nested = body['identification'];
        final data = nested is Map<String, dynamic> ? nested : body;
        setState(() => identification = data);
      } else {
        setState(() => error = body['error']?.toString() ?? 'Não foi possível identificar a planta.');
      }
    } catch (e) {
      setState(() => error = 'Erro técnico: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = identification;
    final results = (result?['results'] as List?) ?? const [];
    final first = results.isNotEmpty ? results.first as Map : null;
    final species = first?['species'] as Map?;
    final scientific = species?['scientificNameWithoutAuthor']?.toString() ?? 'Espécie não informada';
    final commonNames = (species?['commonNames'] as List?)?.whereType<String>().toList() ?? [];
    final confidence = first?['score'] is num ? ((first!['score'] as num) * 100).toStringAsFixed(1) : null;

    return Scaffold(
      appBar: AppBar(
        title: Row(children: const [Icon(Icons.eco, color: Color(0xFF16865B)), SizedBox(width: 9), Text('Botânico IA', style: TextStyle(fontWeight: FontWeight.w800))]),
        actions: [IconButton(onPressed: () => showAboutDialog(context: context, applicationName: 'Botânico IA', applicationVersion: '0.1.0', children: const [Text('Identificação botânica assistida por inteligência artificial. Os resultados são sugestões e devem ser confirmados quando houver risco à saúde ou ao cultivo.')]), icon: const Icon(Icons.info_outline))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF126C4B), Color(0xFF239B69)]), borderRadius: BorderRadius.circular(26)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Seu botânico de bolso', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
            SizedBox(height: 8), Text('Descubra plantas, conheça suas características e aprenda a cuidar melhor delas.', style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4)),
            SizedBox(height: 16), Icon(Icons.local_florist, color: Colors.white, size: 42),
          ]),
        ),
        const SizedBox(height: 22),
        const Text('Identificar uma planta', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Fotografe uma folha, flor ou fruto. Imagens nítidas ajudam a melhorar o resultado.', style: TextStyle(color: Colors.black54, height: 1.4)),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => chooseImage(ImageSource.gallery),
          child: Container(height: 230, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFD8E5DB))), clipBehavior: Clip.antiAlias,
            child: selectedImage == null
              ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_a_photo_outlined, size: 48, color: Color(0xFF16865B)), SizedBox(height: 12), Text('Toque para escolher uma foto', style: TextStyle(fontWeight: FontWeight.w600)), SizedBox(height: 4), Text('JPG ou PNG', style: TextStyle(color: Colors.black45))])
              : Image.file(selectedImage!, fit: BoxFit.cover, width: double.infinity)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: loading ? null : () => chooseImage(ImageSource.camera), icon: const Icon(Icons.camera_alt_outlined), label: const Text('Câmera'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: loading ? null : () => chooseImage(ImageSource.gallery), icon: const Icon(Icons.photo_library_outlined), label: const Text('Galeria'), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)))),
        ]),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: selectedImage == null || loading ? null : identifyPlant, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome), label: Text(loading ? 'Analisando imagem...' : 'Identificar com IA'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: const Color(0xFF16865B))),
        if (error != null) ...[const SizedBox(height: 12), _MessageCard(text: error!, isError: true)],
        if (result != null) ...[
          const SizedBox(height: 22),
          const Text('Resultado da identificação', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _MessageCard(text: commonNames.isEmpty ? scientific : commonNames.take(3).join(' • '), isError: false),
          const SizedBox(height: 10),
          Text(scientific, style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)),
          if (confidence != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Pontuação de correspondência: $confidence%', style: const TextStyle(color: Colors.black54))),
          const SizedBox(height: 10),
          const Text('A pontuação indica a correspondência do modelo, não uma garantia de identificação correta. Confira características da planta antes de consumir ou aplicar tratamentos.'),
          if (results.length > 1) ...[
            const SizedBox(height: 16), const Text('Outras possibilidades', style: TextStyle(fontWeight: FontWeight.bold)),
            for (final item in results.skip(1).take(4)) _AlternativeResult(item: item as Map),
          ],
        ],
        const SizedBox(height: 26),
        const Text('Em breve', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        const _FeatureTile(icon: Icons.health_and_safety_outlined, title: 'Saúde da planta', subtitle: 'Análise orientativa de manchas, pragas e sinais de estresse.'),
        const _FeatureTile(icon: Icons.menu_book_outlined, title: 'Guia de cultivo', subtitle: 'Luz, água, solo, poda e adubação.'),
        const _FeatureTile(icon: Icons.history, title: 'Meu jardim', subtitle: 'Histórico e coleção das plantas identificadas.'),
        const SizedBox(height: 16),
        const Text('A identificação é uma orientação automatizada. Não use o aplicativo como única fonte para decidir se uma planta é comestível, medicinal ou segura para animais.', style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.4)),
      ]),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final String text; final bool isError;
  const _MessageCard({required this.text, required this.isError});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: isError ? const Color(0xFFFFF0ED) : const Color(0xFFE5F4E9), borderRadius: BorderRadius.circular(16)), child: Text(text, style: TextStyle(color: isError ? Colors.red.shade900 : const Color(0xFF145B3D), fontWeight: FontWeight.w600)));
}

class _FeatureTile extends StatelessWidget {
  final IconData icon; final String title; final String subtitle;
  const _FeatureTile({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Card(color: Colors.white, elevation: 0, child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFE5F4E9), child: Icon(icon, color: const Color(0xFF16865B))), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(subtitle)));
}

class _AlternativeResult extends StatelessWidget {
  final Map item;
  const _AlternativeResult({required this.item});
  @override
  Widget build(BuildContext context) {
    final species = item['species'] as Map?;
    final name = species?['scientificNameWithoutAuthor']?.toString() ?? 'Nome indisponível';
    final score = item['score'] is num ? '${((item['score'] as num) * 100).toStringAsFixed(1)}%' : '';
    return ListTile(contentPadding: EdgeInsets.zero, title: Text(name, style: const TextStyle(fontStyle: FontStyle.italic)), trailing: Text(score));
  }
}
