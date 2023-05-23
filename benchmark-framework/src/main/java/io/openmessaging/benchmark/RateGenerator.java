/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package io.openmessaging.benchmark;


import java.time.LocalTime;
import java.util.Map;
import java.util.NavigableMap;
import java.util.TreeMap;
import lombok.extern.slf4j.Slf4j;

@Slf4j
public class RateGenerator {
    private final NavigableMap<LocalTime, Double> ratePoints = new TreeMap<>();

    public void put(LocalTime time, double rate) {
        ratePoints.put(time, rate);
    }

    public double get(LocalTime time) {
        if (ratePoints.isEmpty()) {
            return 0;
        }

        int floorTime;
        int ceilingTime;
        double floorRate;
        double ceilingRate;
        Map.Entry<LocalTime, Double> floorEntry = ratePoints.floorEntry(time);
        if (null == floorEntry) {
            floorTime = ratePoints.lastKey().toSecondOfDay() - 24 * 60 * 60;
            floorRate = ratePoints.lastEntry().getValue();
        } else {
            floorTime = floorEntry.getKey().toSecondOfDay();
            floorRate = floorEntry.getValue();
        }
        Map.Entry<LocalTime, Double> ceilingEntry = ratePoints.ceilingEntry(time);
        if (null == ceilingEntry) {
            ceilingTime = ratePoints.firstKey().toSecondOfDay() + 24 * 60 * 60;
            ceilingRate = ratePoints.firstEntry().getValue();
        } else {
            ceilingTime = ceilingEntry.getKey().toSecondOfDay();
            ceilingRate = ceilingEntry.getValue();
        }
        return calculateY(floorTime, floorRate, ceilingTime, ceilingRate, time.toSecondOfDay());
    }

    private double calculateY(int x1, double y1, int x2, double y2, int x) {
        if (x1 == x2) {
            return y1;
        }
        return y1 + (x - x1) * (y2 - y1) / (x2 - x1);
    }
}
