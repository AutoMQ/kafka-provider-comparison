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


import io.openmessaging.benchmark.utils.distributor.KeyDistributorType;
import java.util.List;

public class Workload {
    public String name;

    /** Number of topics to create in the test. */
    public int topics;

    /** Number of partitions each topic will contain. */
    public int partitionsPerTopic;

    /**
     * If not null, its size must be equal to the number of topics, and it will be used to override
     * the {@link #partitionsPerTopic} value for each topic.
     */
    public List<Integer> partitionsPerTopicList = null;

    /**
     * If true, the topic names will have a random suffix. This is useful to avoid conflicts when
     * running multiple tests against the same cluster.
     */
    public boolean randomTopicNames = true;

    public KeyDistributorType keyDistributor = KeyDistributorType.NO_KEY;

    public int messageSize;

    public boolean useRandomizedPayloads;
    public double randomBytesRatio;
    public int randomizedPayloadPoolSize;

    public String payloadFile;

    public int subscriptionsPerTopic;

    public int producersPerTopic;

    /**
     * If not null, its size must be equal to the number of topics, and it will be used to override
     * the {@link #producersPerTopic} value for each topic.
     */
    public List<Integer> producersPerTopicList = null;

    public int consumerPerSubscription;

    public int producerRate;

    /**
     * If not null, producerRate will be ignored and the producer will use the list to set the rate at
     * different times. It supports two formats:
     * <li>[[hour, minute, rate], [hour, minute, rate], ...] - the rate will be set at the given hour
     *     and minute. For example, [[0, 0, 1000], [1, 30, 2000]] will set the rate to 1000 msg/s at
     *     00:00 and 2000 msg/s at 01:30.
     * <li>[[duration, rate], [duration, rate], ...] - the rate will be set at the given duration (in
     *     minutes) after the test starts. For example, [[0, 1000], [10, 2000], [20, 4000]] will set
     *     the rate to 1000 msg/s at the beginning, 2000 msg/s after 10 minutes, and 4000 msg/s after
     *     20 minutes (from the start of the test).
     */
    public List<List<Integer>> producerRateList = null;

    /**
     * If the consumer backlog is > 0, the generator will accumulate messages until the requested
     * amount of storage is retained and then it will start the consumers to drain it.
     *
     * <p>The testDurationMinutes will be overruled to allow the test to complete when the consumer
     * has drained all the backlog and it's on par with the producer
     */
    public long consumerBacklogSizeGB = 0;
    /**
     * The ratio of the backlog that can remain and yet the backlog still be considered empty, and
     * thus the workload can complete at the end of the configured duration. In some systems it is not
     * feasible for the backlog to be drained fully and thus the workload will run indefinitely. In
     * such circumstances, one may be content to achieve a partial drain such as 99% of the backlog.
     * The value should be on somewhere between 0.0 and 1.0, where 1.0 indicates that the backlog
     * should be fully drained, and 0.0 indicates a best effort, where the workload will complete
     * after the specified time irrespective of how much of the backlog has been drained.
     */
    public double backlogDrainRatio = 1.0;

    public int testDurationMinutes;

    public int warmupDurationMinutes = 1;

    public int logIntervalMillis = 10000;
}
