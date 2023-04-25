
# Benchmarking HDFS
 
https://subscription.packtpub.com/book/big-data-/9781783285471/1/ch01lvl1sec17/benchmarking-hdfs-using-dfsio

With 64 files:
```
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-*-tests.jar TestDFSIO -write -nrFiles 64 -size "1000"
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-*-tests.jar TestDFSIO -read -nrFiles 64 -size "1000"
```

With 128 files:
```
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-*-tests.jar TestDFSIO -write -nrFiles 128 -size "1000"
hadoop jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-client-jobclient-*-tests.jar TestDFSIO -read -nrFiles 128 -size "1000"
```
