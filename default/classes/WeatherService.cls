public with sharing class WeatherService {

    // DTO returned to LWC
    public class WeatherDTO {
        @AuraEnabled public Id locationId;
        @AuraEnabled public String locationName;
        @AuraEnabled public Decimal temperature;
        @AuraEnabled public Decimal humidity;
        @AuraEnabled public Decimal pressure;
        @AuraEnabled public String description;
        @AuraEnabled public Decimal windSpeed;
        @AuraEnabled public String iconCode;
        @AuraEnabled public Datetime retrievedAt;
        @AuraEnabled public Datetime lastUpdatedLocation;
        @AuraEnabled public String status;
    }

    // --- LWC: initial load (no callout) ---
    @AuraEnabled(cacheable=true)
    public static WeatherDTO getLatestWeatherForLocation(Id locationId) {
        if (locationId == null) {
            throw new AuraHandledException('Location Id is required.');
        }

        Location__c loc = [
            SELECT Id, Name, Last_Weather_Updated__c, Last_Weather_Status__c
            FROM Location__c
            WHERE Id = :locationId
            LIMIT 1
        ];

        WeatherInfo__c wi;
        List<WeatherInfo__c> listWi = [
            SELECT Id, Temperature__c, Humidity__c, Pressure__c,
                   Description__c, WindSpeed__c, IconCode__c, RetrievedAt__c
            FROM WeatherInfo__c
            WHERE Location__c = :locationId AND IsLatest__c = true
            ORDER BY RetrievedAt__c DESC
            LIMIT 1
        ];
        if (!listWi.isEmpty()) {
            wi = listWi[0];
        }

        return toDTO(loc, wi);
    }

    // --- LWC: "Refresh / Get Weather Details" button ---
    // Updated so that it always updates Last_Weather_Updated__c / Last_Weather_Status__c
    // and returns a DTO instead of throwing after DML.
    @AuraEnabled(cacheable=false)
    public static WeatherDTO refreshWeatherForLocation(Id locationId) {
        if (locationId == null) {
            throw new AuraHandledException('Location Id is required.');
        }

        Location__c loc = [
            SELECT Id, Name, Latitude__c, Longitude__c,
                   Last_Weather_Updated__c, Last_Weather_Status__c
            FROM Location__c
            WHERE Id = :locationId
            LIMIT 1
        ];

        WeatherInfo__c wi;

        try {
            // Guard: require coordinates before calling API
            if (loc.Latitude__c == null || loc.Longitude__c == null) {
                loc.Last_Weather_Updated__c = System.now();
                loc.Last_Weather_Status__c  = 'Error: Latitude and Longitude are required.';
                update loc;
                // No WeatherInfo__c; return DTO with error status
                return toDTO(loc, null);
            }

            // Call external Weather API
            WeatherApiClient.CurrentWeatherResponse apiRes =
                WeatherApiClient.getCurrentWeather(loc.Latitude__c, loc.Longitude__c);

            // Map and save weather
            wi = createWeatherInfo(
                loc,
                apiRes,
                JSON.serialize(apiRes)
            );
            saveLatestWeather(wi);

            // Mark success on Location
            loc.Last_Weather_Updated__c = System.now();
            loc.Last_Weather_Status__c  = 'Success';
            update loc;

            return toDTO(loc, wi);

        } catch (WeatherApiClient.WeatherException e) {
            // Known integration error – record details on the Location, no rollback
            loc.Last_Weather_Updated__c = System.now();
            loc.Last_Weather_Status__c  = 'Error: ' + e.getMessage();
            update loc;

            // Return DTO with error status, without throwing
            return toDTO(loc, null);

        } catch (Exception e) {
            // Unexpected error – also recorded on the Location
            loc.Last_Weather_Updated__c = System.now();
            loc.Last_Weather_Status__c  = 'Unexpected error: ' + e.getMessage();
            update loc;

            return toDTO(loc, null);
        }
    }

    // --- Shared mapping: API -> WeatherInfo__c ---
    public static WeatherInfo__c createWeatherInfo(
        Location__c loc,
        WeatherApiClient.CurrentWeatherResponse apiRes,
        String rawJson
    ) {
        WeatherInfo__c wi = new WeatherInfo__c();
        wi.Location__c = loc.Id;

        if (apiRes.main != null) {
            wi.Temperature__c = apiRes.main.temp;
            wi.Humidity__c    = apiRes.main.humidity;
            wi.Pressure__c    = apiRes.main.pressure;
        }
        if (apiRes.weather != null && !apiRes.weather.isEmpty()) {
            wi.Description__c = apiRes.weather[0].description;
            wi.IconCode__c    = apiRes.weather[0].icon;
        }
        if (apiRes.wind != null) {
            wi.WindSpeed__c = apiRes.wind.speed;
        }

        wi.RetrievedAt__c = System.now();
        wi.IsLatest__c    = true;
        wi.RawResponse__c = rawJson;
        return wi;
    }

    // --- Maintain IsLatest__c flag for one location (LWC path) ---
    public static void saveLatestWeather(WeatherInfo__c latest) {
        List<WeatherInfo__c> existing = [
            SELECT Id, IsLatest__c
            FROM WeatherInfo__c
            WHERE Location__c = :latest.Location__c AND IsLatest__c = true
        ];
        for (WeatherInfo__c e : existing) {
            e.IsLatest__c = false;
        }
        if (!existing.isEmpty()) {
            update existing;
        }
        insert latest;
    }

    // --- Map Location + WeatherInfo to DTO for LWC ---
    private static WeatherDTO toDTO(Location__c loc, WeatherInfo__c wi) {
        WeatherDTO dto = new WeatherDTO();
        dto.locationId          = loc.Id;
        dto.locationName        = loc.Name;
        dto.lastUpdatedLocation = loc.Last_Weather_Updated__c;
        dto.status              = loc.Last_Weather_Status__c;

        if (wi != null) {
            dto.temperature = wi.Temperature__c;
            dto.humidity    = wi.Humidity__c;
            dto.pressure    = wi.Pressure__c;
            dto.description = wi.Description__c;
            dto.windSpeed   = wi.WindSpeed__c;
            dto.iconCode    = wi.IconCode__c;
            dto.retrievedAt = wi.RetrievedAt__c;
        }
        return dto;
    }
}
