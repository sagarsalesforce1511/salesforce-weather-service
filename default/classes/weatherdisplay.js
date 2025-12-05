import { LightningElement, api, wire, track } from 'lwc';
import getLatestWeatherForLocation from '@salesforce/apex/WeatherService.getLatestWeatherForLocation';
import refreshWeatherForLocation from '@salesforce/apex/WeatherService.refreshWeatherForLocation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// Optional: if you want the standard record details to refresh too
// import { getRecordNotifyChange } from 'lightning/uiRecordApi';

export default class WeatherDisplay extends LightningElement {
    @api recordId;
    @track weather;
    @track loading = false;
    @track error;

    @wire(getLatestWeatherForLocation, { locationId: '$recordId' })
    wiredWeather({ data, error }) {
        if (data) {
            this.weather = data;
            this.error = undefined;
        } else if (error) {
            this.weather = undefined;
            this.error = error.body ? error.body.message : error.message;
        }
    }

    get hasWeather() {
        // Consider we "have weather" if we have any DTO at all
        return this.weather != null;
    }

    get temperature() {
        return this.weather && this.weather.temperature != null
            ? this.weather.temperature
            : null;
    }

    get description() {
        return this.weather && this.weather.description
            ? this.weather.description
            : null;
    }

    get humidity() {
        return this.weather && this.weather.humidity != null
            ? this.weather.humidity
            : null;
    }

    get windSpeed() {
        return this.weather && this.weather.windSpeed != null
            ? this.weather.windSpeed
            : null;
    }

    get retrievedAt() {
        return this.weather && this.weather.retrievedAt
            ? this.weather.retrievedAt
            : null;
    }

    get lastUpdatedLocation() {
        return this.weather && this.weather.lastUpdatedLocation
            ? this.weather.lastUpdatedLocation
            : null;
    }

    get lastStatus() {
        return this.weather && this.weather.status
            ? this.weather.status
            : null;
    }

    handleRefresh() {
        this.loading = true;
        this.error = undefined;

        refreshWeatherForLocation({ locationId: this.recordId })
            .then(result => {
                this.weather = result;

                // Optional: refresh the standard record details
                // getRecordNotifyChange([{ recordId: this.recordId }]);

                const status = result.status || '';

                if (status.startsWith('Error') || status.startsWith('Unexpected')) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error refreshing weather',
                            message: status,
                            variant: 'error'
                        })
                    );
                } else {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Weather updated',
                            message: 'Latest weather data has been retrieved.',
                            variant: 'success'
                        })
                    );
                }
            })
            .catch(err => {
                const msg = err.body ? err.body.message : err.message;
                this.error = msg;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: msg,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.loading = false;
            });
    }
}
