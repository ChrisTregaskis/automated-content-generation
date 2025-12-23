#!/bin/bash

# Create directories
mkdir -p products lifestyle brand events

# Products - Supersports
curl -o "products/supersports-rear.jpg" "http://artofbrand.se/wp-content/uploads/2015/11/Automotive_Bentley_Supersport_006.jpg"
curl -o "products/supersports-profile.jpg" "http://artofbrand.se/wp-content/uploads/2015/11/Automotive_Bentley_Supersport_007.jpg"
curl -o "products/supersports-detail.jpg" "http://artofbrand.se/wp-content/uploads/2015/11/Automotive_Bentley_Supersport_010.jpg"
curl -o "products/supersports-showroom.jpg" "https://artofbrand.se/wp-content/uploads/2015/11/Automotive_Bentley_Supersport_005B.jpg"
curl -o "products/engine-heritage-plaque.jpg" "https://artofbrand.se/wp-content/uploads/2015/11/Automotive_Bentley_Supersport_003B.jpg"

# Products - Continental
curl -o "products/continental-driving.jpg" "http://artofbrand.se/wp-content/uploads/2015/11/Automotive_Bentley-Continental_012.jpg"

# Products - Mulsanne
curl -o "products/mulsanne-studio.jpg" "https://artofbrand.se/wp-content/uploads/2015/11/Automotive_Bentley-Mulsanne_003A.jpg"

# Lifestyle
curl -o "lifestyle/silhouette-car-owner-bw.jpg" "https://artofbrand.se/wp-content/uploads/2014/11/People_Bentley-Motors_002.jpg"
curl -o "lifestyle/owner-portrait-bw.jpg" "https://artofbrand.se/wp-content/uploads/2014/11/People_Bentley-Motors_007.jpg"
curl -o "lifestyle/craftsmanship-wood-veneer.jpg" "https://artofbrand.se/wp-content/uploads/2015/11/Automotive_Bentley-Continental_010A.jpg"
curl -o "lifestyle/environment-tree.jpg" "https://artofbrand.se/wp-content/uploads/2015/11/Automotive_Bentley-Continental_010B.jpg"

# Brand - Advertising
curl -o "brand/ad-mulsanne-print.jpg" "http://artofbrand.se/wp-content/uploads/2014/11/clients_Bentley_3041.jpg"
curl -o "brand/ad-supersport-print-01.jpg" "http://artofbrand.se/wp-content/uploads/2014/11/clients_Bentley_3051.jpg"
curl -o "brand/ad-supersport-print-02.jpg" "http://artofbrand.se/wp-content/uploads/2014/11/clients_Bentley_3061.jpg"
curl -o "brand/ad-continental-print.jpg" "http://artofbrand.se/wp-content/uploads/2014/11/clients_Bentley_303.jpg"
curl -o "brand/website-mulsanne.jpg" "http://artofbrand.se/wp-content/uploads/2014/11/clients_Bentley_3091.jpg"
curl -o "brand/website-continental.jpg" "http://artofbrand.se/wp-content/uploads/2014/11/clients_Bentley_308.jpg"
curl -o "brand/abstract-bokeh.jpg" "https://artofbrand.se/wp-content/uploads/2015/11/Automotive_Bentley_Supersport_005A.jpg"

# Events
curl -o "events/motorshow-frankfurt-01.jpg" "https://artofbrand.se/wp-content/uploads/2014/11/clients_Bentley_5011.jpg"
curl -o "events/motorshow-frankfurt-02.jpg" "https://artofbrand.se/wp-content/uploads/2014/11/clients_Bentley_5041.jpg"
curl -o "events/ice-record-01.jpg" "https://artofbrand.se/wp-content/uploads/2014/11/clients_Bentley_5071.jpg"
curl -o "events/ice-record-02.jpg" "https://artofbrand.se/wp-content/uploads/2014/11/clients_Bentley_5081.jpg"

echo "Download complete! $(find . -name '*.jpg' | wc -l) images downloaded."