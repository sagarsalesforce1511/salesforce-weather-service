public with sharing class WeatherApiClient {
    public class WeatherException extends Exception {}

    private static final String NAMED_CRED = 'OpenWeather';

    // Top-level inner response class
    public class CurrentWeatherResponse {
        public Main main;
        public List<Weather> weather;
        public Wind wind;
        public String name;
        public Sys sys;
        public Long dt;
    }

    // Sibling inner classes (NOT nested inside CurrentWeatherResponse)

    public class Main {
        public Decimal temp;
        public Decimal feels_like;
        public Decimal temp_min;
        public Decimal temp_max;
        public Decimal pressure;
        public Decimal humidity;
    }

    public class Weather {
        public Integer id;
        public String main;
        public String description;
        public String icon;
    }

    public class Wind {
        public Decimal speed;
        public Decimal deg;
        public Decimal gust;
    }

    public class Sys {
        public String country;
    }

    public static CurrentWeatherResponse getCurrentWeather(Decimal lat, Decimal lon) {
        if (lat == null || lon == null) {
            throw new WeatherException('Latitude and Longitude are required.');
        }

        Weather_Config__mdt cfg = Weather_Config__mdt.getInstance('Default');
        if (cfg == null || String.isBlank(cfg.ApiKey__c)) {
            throw new WeatherException('Weather configuration (API key) is missing.');
        }

        String units = String.isBlank(cfg.Units__c) ? 'metric' : cfg.Units__c;
        String lang  = String.isBlank(cfg.Lang__c)  ? 'en'     : cfg.Lang__c;

        HttpRequest req = new HttpRequest();
        req.setMethod('GET');

        String endpoint = 'callout:' + NAMED_CRED +
            '/data/2.5/weather' +
            '?lat=' + String.valueOf(lat) +
            '&lon=' + String.valueOf(lon) +
            '&appid=' + EncodingUtil.urlEncode(cfg.ApiKey__c, 'UTF-8') +
            '&units=' + EncodingUtil.urlEncode(units, 'UTF-8') +
            '&lang='  + EncodingUtil.urlEncode(lang, 'UTF-8');

        req.setEndpoint(endpoint);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new WeatherException(
                'Weather API error ' + res.getStatusCode() + ': ' + res.getStatus()
            );
        }

        return (CurrentWeatherResponse) JSON.deserialize(
            res.getBody(), CurrentWeatherResponse.class
        );
    }
}
