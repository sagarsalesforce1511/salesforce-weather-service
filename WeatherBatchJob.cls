public with sharing class WeatherBatchJob implements Database.Batchable<SObject>, Database.AllowsCallouts {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator(
            'SELECT Id, Name, Latitude__c, Longitude__c, ' +
            'Last_Weather_Updated__c, Last_Weather_Status__c ' +
            'FROM Location__c ' +
            'WHERE Latitude__c != null AND Longitude__c != null'
        );
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<Location__c> locs = (List<Location__c>) scope;

        Set<Id> locIds = new Set<Id>();
        for (Location__c l : locs) {
            locIds.add(l.Id);
        }

        // Existing latest weather records
        Map<Id, List<WeatherInfo__c>> existingByLoc = new Map<Id, List<WeatherInfo__c>>();
        if (!locIds.isEmpty()) {
            for (WeatherInfo__c wi : [
                SELECT Id, Location__c, IsLatest__c
                FROM WeatherInfo__c
                WHERE Location__c IN :locIds AND IsLatest__c = true
            ]) {
                if (!existingByLoc.containsKey(wi.Location__c)) {
                    existingByLoc.put(wi.Location__c, new List<WeatherInfo__c>());
                }
                existingByLoc.get(wi.Location__c).add(wi);
            }
        }

        List<WeatherInfo__c> toInsert = new List<WeatherInfo__c>();
        List<WeatherInfo__c> toUnset  = new List<WeatherInfo__c>();
        List<Location__c> locToUpdate = new List<Location__c>();

        for (Location__c loc : locs) {
            try {
                WeatherApiClient.CurrentWeatherResponse apiRes =
                    WeatherApiClient.getCurrentWeather(loc.Latitude__c, loc.Longitude__c);

                WeatherInfo__c wi = WeatherService.createWeatherInfo(
                    loc, apiRes, JSON.serialize(apiRes)
                );
                toInsert.add(wi);

                if (existingByLoc.containsKey(loc.Id)) {
                    for (WeatherInfo__c oldWi : existingByLoc.get(loc.Id)) {
                        oldWi.IsLatest__c = false;
                        toUnset.add(oldWi);
                    }
                }

                loc.Last_Weather_Updated__c = System.now();
                loc.Last_Weather_Status__c  = 'Success';
                locToUpdate.add(loc);

            } catch (Exception e) {
                loc.Last_Weather_Status__c = 'Batch error: ' + e.getMessage();
                locToUpdate.add(loc);
            }
        }

        if (!toUnset.isEmpty())     update toUnset;
        if (!toInsert.isEmpty())    insert toInsert;
        if (!locToUpdate.isEmpty()) update locToUpdate;
    }

    public void finish(Database.BatchableContext bc) {
        // Optional logging or chaining
    }
}
