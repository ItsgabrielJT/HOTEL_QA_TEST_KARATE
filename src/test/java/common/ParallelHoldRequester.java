package common;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

public final class ParallelHoldRequester {

    private ParallelHoldRequester() {
    }

    public static List<Map<String, Object>> createHolds(String baseUrl,
                                                        String roomId,
                                                        String checkin,
                                                        String checkout,
                                                        Map<String, Object> headers) {
        HttpClient client = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
        ExecutorService executor = Executors.newFixedThreadPool(2);
        String endpoint = baseUrl + "/rooms/" + roomId + "/hold";
        String body = String.format("{\"checkin\":\"%s\",\"checkout\":\"%s\"}", checkin, checkout);

        Callable<Map<String, Object>> task = () -> sendRequest(client, endpoint, body, headers);

        try {
            List<Future<Map<String, Object>>> futures = executor.invokeAll(List.of(task, task));
            List<Map<String, Object>> responses = new ArrayList<>();
            for (int index = 0; index < futures.size(); index++) {
                Map<String, Object> result = futures.get(index).get();
                result.put("requestIndex", index + 1);
                responses.add(result);
            }
            return responses;
        } catch (Exception exception) {
            throw new RuntimeException("No se pudieron ejecutar las solicitudes concurrentes de hold", exception);
        } finally {
            executor.shutdownNow();
        }
    }

    private static Map<String, Object> sendRequest(HttpClient client,
                                                   String endpoint,
                                                   String body,
                                                   Map<String, Object> headers) throws Exception {
        HttpRequest.Builder builder = HttpRequest.newBuilder()
                .uri(URI.create(endpoint))
                .timeout(Duration.ofSeconds(20))
                .header("Content-Type", "application/json")
                .header("Accept", "application/json");

        if (headers != null) {
            headers.forEach((key, value) -> {
                if (value != null && !String.valueOf(value).isBlank()) {
                    builder.header(key, String.valueOf(value));
                }
            });
        }

        HttpResponse<String> response = client.send(builder.POST(HttpRequest.BodyPublishers.ofString(body)).build(),
                HttpResponse.BodyHandlers.ofString());

        Map<String, Object> result = new HashMap<>();
        result.put("status", response.statusCode());
        result.put("body", response.body());
        return result;
    }
}
