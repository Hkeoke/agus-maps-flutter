package app.agus.maps.agus_maps_flutter;

public class SearchResult {
    public final String name;
    public final String address;
    public final double lat;
    public final double lon;
    
    public SearchResult(String name, String address, double mercatorX, double mercatorY) {
        this.name = name;
        this.address = address;
        
        // Convert from Mercator to lat/lon
        this.lon = mercatorX * 180.0 / Math.PI;
        this.lat = Math.toDegrees(2.0 * Math.atan(Math.exp(mercatorY)) - Math.PI / 2.0);
    }
}
