# usage cost explanation

## S3 Usage

The estimation of API invoke is that 800MB of storage corresponds to 25 PUTs and 10 GETs. We have estimated that each GB
corresponds to 31.25 PUTs and 12.5 GETs. Assuming a peak throughput of 0.5 GB/s and an average throughput of 0.25
GB/s, with data retention for 7 days, the data volume for 30 days is:

``` 
24*3600*0.25GB/s = 21600GB
```