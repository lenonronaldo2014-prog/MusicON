// SPDX-License-Identifier: GPL-3.0-or-later
package com.musicon.desktop;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import java.io.*;
import java.net.URI;
import java.net.http.*;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.*;
import org.schabi.newpipe.extractor.*;
import org.schabi.newpipe.extractor.downloader.*;
import org.schabi.newpipe.extractor.localization.Localization;
import org.schabi.newpipe.extractor.search.SearchInfo;
import org.schabi.newpipe.extractor.stream.*;
import org.schabi.newpipe.extractor.services.youtube.YoutubeParsingHelper;

/** Private JSON-lines subprocess; never exposes a network control port. */
public final class ExtractorMain {
    public static void main(String[] args) throws Exception {
        final PrintStream protocol = new PrintStream(
                new FileOutputStream(FileDescriptor.out), true, StandardCharsets.UTF_8);
        System.setOut(new PrintStream(OutputStream.nullOutputStream()));
        NewPipe.init(new DesktopDownloader(), new Localization("pt", "BR"));
        Gson gson = new Gson();
        BufferedReader input = new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8));
        String line;
        while ((line = input.readLine()) != null) {
            Map<String, Object> reply = new LinkedHashMap<>();
            try {
                JsonObject request = gson.fromJson(line, JsonObject.class);
                reply.put("id", request.get("id").getAsInt());
                String method = request.get("method").getAsString();
                String value = request.has("value") ? request.get("value").getAsString().trim() : "";
                if (value.length() > 500) throw new IllegalArgumentException();
                Object data = switch (method) {
                    case "ping" -> Map.of("version", "v0.27.0");
                    case "search" -> search(value);
                    case "resolve" -> resolve(value);
                    default -> throw new IllegalArgumentException();
                };
                reply.put("data", data);
            } catch (Exception | LinkageError error) {
                reply.put("error", "A fonte não respondeu. Confira a conexão ou tente outra música.");
                reply.put("type", error.getClass().getSimpleName());
            }
            protocol.println(gson.toJson(reply));
            protocol.flush();
        }
    }

    private static List<Map<String, Object>> search(String query) throws Exception {
        if (query.isBlank()) throw new IllegalArgumentException();
        var service = NewPipe.getService(0);
        var handler = service.getSearchQHFactory().fromQuery(query, List.of("videos"), "");
        var info = SearchInfo.getInfo(service, handler);
        var results = new ArrayList<Map<String, Object>>();
        for (var item : info.getRelatedItems()) {
            if (!(item instanceof StreamInfoItem video)) continue;
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("title", video.getName()); row.put("artist", video.getUploaderName());
            row.put("url", video.getUrl()); row.put("duration", video.getDuration());
            row.put("artwork", artwork(video.getThumbnails()));
            results.add(row);
            if (results.size() == 20) break;
        }
        return results;
    }

    private static String artwork(List<Image> images) {
        return images.stream().max(Comparator.comparingInt(Image::getWidth)).map(Image::getUrl).orElse(null);
    }

    private static Map<String, Object> resolve(String url) throws Exception {
        URI uri = URI.create(url);
        String host = Objects.requireNonNullElse(uri.getHost(), "").toLowerCase(Locale.ROOT);
        if (!"https".equals(uri.getScheme()) || uri.getUserInfo() != null ||
            !(host.equals("youtu.be") || host.equals("youtube.com") || host.endsWith(".youtube.com"))) {
            throw new IllegalArgumentException();
        }
        var service = NewPipe.getService(0);
        if (!service.getStreamLHFactory().acceptUrl(url)) throw new IllegalArgumentException();
        var info = StreamInfo.getInfo(service, url);
        var audio = info.getAudioStreams().stream().filter(stream -> stream.isUrl() &&
            stream.getDeliveryMethod() == DeliveryMethod.PROGRESSIVE_HTTP && stream.getContent().startsWith("https://"))
            .max(Comparator.comparingInt(AudioStream::getAverageBitrate)).orElseThrow(IOException::new);
        Map<String, String> headers = new LinkedHashMap<>();
        headers.put("User-Agent", YoutubeParsingHelper.isVisionOsStreamingUrl(audio.getContent()) ?
            YoutubeParsingHelper.getVisionOsUserAgent(null) : "Mozilla/5.0");
        if (YoutubeParsingHelper.isWebStreamingUrl(audio.getContent())) {
            headers.put("Origin", "https://www.youtube.com"); headers.put("Referer", "https://www.youtube.com");
        }
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("title", info.getName()); result.put("artist", info.getUploaderName()); result.put("url", info.getUrl());
        result.put("stream", audio.getContent()); result.put("headers", headers); result.put("artwork", artwork(info.getThumbnails()));
        return result;
    }

    private static final class DesktopDownloader extends Downloader {
        private final HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(15))
            .followRedirects(HttpClient.Redirect.NORMAL).build();
        @Override public Response execute(Request request) throws IOException {
            var builder = HttpRequest.newBuilder(URI.create(request.url())).timeout(Duration.ofSeconds(25));
            builder.header("User-Agent", "Mozilla/5.0").header("Accept-Encoding", "identity");
            request.headers().forEach((name, values) -> {
                if (!Set.of("connection", "content-length", "host", "expect", "upgrade").contains(name.toLowerCase(Locale.ROOT))) {
                    builder.setHeader(name, String.join(", ", values));
                }
            });
            byte[] data = request.dataToSend();
            builder.method(request.httpMethod(), data == null ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofByteArray(data));
            try {
                var response = client.send(builder.build(), HttpResponse.BodyHandlers.ofInputStream());
                byte[] bytes;
                try (var stream = response.body()) { bytes = stream.readNBytes(8 * 1024 * 1024 + 1); }
                if (bytes.length > 8 * 1024 * 1024) throw new IOException("Response too large");
                return new Response(response.statusCode(), "HTTP " + response.statusCode(), response.headers().map(),
                    new String(bytes, StandardCharsets.UTF_8), response.uri().toString());
            } catch (InterruptedException error) {
                Thread.currentThread().interrupt(); throw new IOException("Interrupted", error);
            }
        }
    }
}
