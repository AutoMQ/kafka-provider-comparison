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

import static org.assertj.core.api.Assertions.assertThat;

import java.time.LocalTime;
import org.junit.jupiter.api.Test;

class RateGeneratorTest {
    private final RateGenerator rateGenerator = new RateGenerator();

    @Test
    void empty() {
        assertThat(rateGenerator.get(LocalTime.now())).isEqualTo(0);
    }

    @Test
    void single() {
        rateGenerator.put(LocalTime.of(12, 34), 56);

        assertThat(rateGenerator.get(LocalTime.of(12, 34))).isEqualTo(56);

        assertThat(rateGenerator.get(LocalTime.MIN)).isEqualTo(56);
        assertThat(rateGenerator.get(LocalTime.MAX)).isEqualTo(56);

        assertThat(rateGenerator.get(LocalTime.of(3, 4))).isEqualTo(56);
        assertThat(rateGenerator.get(LocalTime.of(13, 14))).isEqualTo(56);
    }

    @Test
    void multiple() {
        rateGenerator.put(LocalTime.of(3, 0), 100);
        rateGenerator.put(LocalTime.of(12, 0), 1000);
        rateGenerator.put(LocalTime.of(22, 0), 0);

        assertThat(rateGenerator.get(LocalTime.of(3, 0))).isEqualTo(100);
        assertThat(rateGenerator.get(LocalTime.of(12, 0))).isEqualTo(1000);
        assertThat(rateGenerator.get(LocalTime.of(22, 0))).isEqualTo(0);

        assertThat(rateGenerator.get(LocalTime.of(5, 0))).isEqualTo(300);
        assertThat(rateGenerator.get(LocalTime.of(5, 6))).isEqualTo(310);
        assertThat(rateGenerator.get(LocalTime.of(17, 57))).isEqualTo(405);
        assertThat(rateGenerator.get(LocalTime.of(18, 0))).isEqualTo(400);

        assertThat(rateGenerator.get(LocalTime.of(23, 0))).isEqualTo(20);
        assertThat(rateGenerator.get(LocalTime.of(23, 57))).isEqualTo(39);
        assertThat(rateGenerator.get(LocalTime.of(0, 0))).isEqualTo(40);
        assertThat(rateGenerator.get(LocalTime.of(0, 3))).isEqualTo(41);
        assertThat(rateGenerator.get(LocalTime.of(1, 0))).isEqualTo(60);
        assertThat(rateGenerator.get(LocalTime.of(2, 0))).isEqualTo(80);
    }
}
