import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:wargabut/app/ui/components/impacnation/photo_view.dart';

class PostDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<String> posterUrls;

  const PostDetailPage({
    super.key,
    required this.data,
    required this.posterUrls,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> imageSliders = posterUrls
        .map((item) => Container(
              margin: const EdgeInsets.all(5.0),
              child: ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(5.0)),
                  child: Stack(
                    children: <Widget>[
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PhotoViewer(
                                url: item,
                              ),
                            ),
                          );
                        },
                        child: Image.network(
                          item,
                          fit: BoxFit.cover,
                          width: 1000.0,
                        ),
                      ),
                    ],
                  )),
            ))
        .toList();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0.0,
        title: Text(data['title']),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CarouselSlider(
                options: CarouselOptions(
                  autoPlay: true,
                  autoPlayInterval: const Duration(seconds: 8),
                  aspectRatio: 1.2,
                  enlargeCenterPage: true,
                ),
                items: imageSliders,
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info),
                  title: Text(data['location']),
                  subtitle: Text(data['date']),
                ),
              ),
              const SizedBox(height: 16.0),
              SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Text(
                      data['desc'].replaceAll('\\n', '\n'),
                      softWrap: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              Card(
                clipBehavior: Clip.hardEdge,
                child: Column(
                  children: [
                    ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        Theme.of(context).colorScheme.surface.withOpacity(0.5),
                        BlendMode.darken,
                      ),
                      child: const Image(
                        width: double.infinity,
                        height: 130,
                        image: AssetImage('assets/images/Placeholder_Maps.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                      child: Column(
                        children: [
                          Text(
                            data['address'],
                            softWrap: true,
                          ),
                          // Row(
                          //   mainAxisAlignment: MainAxisAlignment.end,
                          //   children: [
                          //     TextButton(
                          //       onPressed: () => MapsLauncher.launchQuery(data['location']),
                          //       child: const Text('Lihat arah'),
                          //     ),
                          //   ],
                          // )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),
            ],
          ),
        ),
      ),
    );
  }
}
