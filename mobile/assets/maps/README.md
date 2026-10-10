# City atlas district geometry

Source: DataV administrative boundaries, https://geo.datav.aliyun.com/areas_v3/bound/{adcode}_full.json

| Catalog slug | City | Adcode | Districts |
| --- | --- | --- | --- |
| shenzhen | 深圳 | 440300 | 9 |
| shanghai | 上海 | 310000 | 16 |
| guangzhou | 广州 | 440100 | 11 |
| zhuhai | 珠海 | 440400 | 3 |
| shangqiu | 商丘 | 411400 | 9 |

Shenzhen was copied from the approved prototype on 2026-10-09; the remaining original GeoJSON files were retrieved on 2026-10-11. Coverage follows seed cities and the published CMS content packages under docs/content-packages. The live catalog endpoint was unreachable during this update.

Maps render offline using Mercator projection. Keep DataV attribution visible. Place coordinates come independently from the content catalog; these maps are for browsing, not navigation. The source represents administrative districts/counties, not every development zone.

When adding a city, save its district FeatureCollection as `<catalog-slug>.geojson` in this directory and extend the coverage regression test. The asset manifest discovers maps without city-specific rendering code. Unknown cities retain their catalog point map; no boundaries are fabricated.
