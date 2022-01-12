-- Databricks notebook source
-- MAGIC %md-sandbox
-- MAGIC 
-- MAGIC <div style="text-align: center; line-height: 0; padding-top: 9px;">
-- MAGIC   <img src="https://databricks.com/wp-content/uploads/2018/03/db-academy-rgb-1200px.png" alt="Databricks Learning" style="width: 600px">
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC # Working with Delta Lake
-- MAGIC 
-- MAGIC This notebook provides a hands-on review of some of the basic functionality of Delta Lake.
-- MAGIC 
-- MAGIC ## Learning Objectives
-- MAGIC By the end of this lessons, student will be able to:
-- MAGIC - Execute standard operations to create and manipulate Delta Lake tables
-- MAGIC - Review table history
-- MAGIC - Query previous table versions and rollback a table to a specific version
-- MAGIC - Perform file compaction and Z-order indexing
-- MAGIC - Preview files marked for permanent deletion and commit these deletes

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Setup
-- MAGIC Run the following script to setup necessary variables and clear out past runs of this notebook. Note that re-executing this cell will allow you to start the lab over.

-- COMMAND ----------

-- MAGIC %run ../Includes/sql-setup $course="delta" $mode="reset"

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Create a Table
-- MAGIC 
-- MAGIC In this notebook, we'll be creating a table to track our bean collection.
-- MAGIC 
-- MAGIC Use the cell below to create a managed Delta Lake table named `beans`.
-- MAGIC 
-- MAGIC Provide the following schema:
-- MAGIC 
-- MAGIC | Field Name | Field type |
-- MAGIC | --- | --- |
-- MAGIC | name | STRING |
-- MAGIC | color | STRING |
-- MAGIC | grams | FLOAT |
-- MAGIC | delicious | BOOLEAN |

-- COMMAND ----------

-- ANSWER
CREATE TABLE beans 
(name STRING, color STRING, grams FLOAT, delicious BOOLEAN); 

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **NOTE**: We'll use Python to run checks occasionally throughout the lab. The following cell will return as error with a message on what needs to change if you have not followed instructions. No output from cell execution means that you have completed this step.

-- COMMAND ----------

-- MAGIC %python
-- MAGIC assert spark.table("beans"), "Table named `beans` does not exist"
-- MAGIC assert spark.table("beans").columns == ["name", "color", "grams", "delicious"], "Please name the columns in the order provided above"
-- MAGIC assert spark.table("beans").dtypes == [("name", "string"), ("color", "string"), ("grams", "float"), ("delicious", "boolean")], "Please make sure the column types are identical to those provided above"

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Insert Data
-- MAGIC 
-- MAGIC Run the following cell to insert three rows into the table.

-- COMMAND ----------

INSERT INTO beans VALUES
("black", "black", 500, true),
("lentils", "brown", 1000, true),
("jelly", "rainbow", 42.5, false)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Manually review the table contents to ensure data was written as expected.

-- COMMAND ----------

-- ANSWER
SELECT * FROM beans

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Insert the additional records provided below. Make sure you execute this as a single transaction.

-- COMMAND ----------

-- ANSWER
INSERT INTO beans VALUES
('pinto', 'brown', 1.5, true),
('green', 'green', 178.3, true),
('beanbag chair', 'white', 40000, false)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Run the cell below to confirm the data is in the proper state.

-- COMMAND ----------

-- MAGIC %python
-- MAGIC assert spark.table("beans").count() == 6, "The table should have 6 records"
-- MAGIC assert spark.conf.get("spark.databricks.delta.lastCommitVersionInSession") == "2", "Only 3 commits should have been made to the table"
-- MAGIC assert set(row["name"] for row in spark.table("beans").select("name").collect()) == {'beanbag chair', 'black', 'green', 'jelly', 'lentils', 'pinto'}, "Make sure you have not modified the data provided"

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Update Records
-- MAGIC 
-- MAGIC A friend is reviewing your inventory of beans. After much debate, you agree that jelly beans are delicious.
-- MAGIC 
-- MAGIC Run the following cell to update this record.

-- COMMAND ----------

UPDATE beans
SET delicious = true
WHERE name = "jelly"

-- COMMAND ----------

-- MAGIC %md
-- MAGIC You realize that you've accidentally entered the weight of your pinto beans incorrectly.
-- MAGIC 
-- MAGIC Update the `grams` column for this record to the correct weight of 1500.

-- COMMAND ----------

-- ANSWER
UPDATE beans
SET grams = 1500
WHERE name = 'pinto'

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Run the cell below to confirm this has completed properly.

-- COMMAND ----------

-- MAGIC %python
-- MAGIC assert spark.table("beans").filter("name='pinto'").count() == 1, "There should only be 1 entry for pinto beans"
-- MAGIC row = spark.table("beans").filter("name='pinto'").first()
-- MAGIC assert row["color"] == "brown", "The pinto bean should be labeled as the color brown"
-- MAGIC assert row["grams"] == 1500, "Make sure you correctly specified the `grams` as 1500"
-- MAGIC assert row["delicious"] == True, "The pinto bean is a delicious bean"

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Delete Records
-- MAGIC 
-- MAGIC You've decided that you only want to keep track of delicious beans.
-- MAGIC 
-- MAGIC Execute a query to drop all beans that are not delicious.

-- COMMAND ----------

-- ANSWER
DELETE FROM beans
WHERE delicious = false

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Run the following cell to confirm this operation was successful.

-- COMMAND ----------

-- MAGIC %python
-- MAGIC assert spark.table("beans").filter("delicious=true").count() == 5, "There should be 5 delicious beans in your table"
-- MAGIC assert spark.table("beans").filter("name='beanbag chair'").count() == 0, "Make sure your logic deletes non-delicious beans"

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Using Merge to Upsert Records
-- MAGIC 
-- MAGIC Your friend gives you some new beans. The cell below registers these as a temporary view.

-- COMMAND ----------

CREATE OR REPLACE TEMP VIEW new_beans(name, color, grams, delicious) AS VALUES
('black', 'black', 60.5, true),
('lentils', 'green', 500, true),
('kidney', 'red', 387.2, true),
('castor', 'brown', 25, false);

SELECT * FROM new_beans

-- COMMAND ----------

-- MAGIC %md
-- MAGIC In the cell below, use the above view to write a merge statement to update and insert new records to your `beans` table as one transaction.
-- MAGIC 
-- MAGIC Make sure your logic:
-- MAGIC - Matches beans by name **and** color
-- MAGIC - Updates existing beans by adding the new weight to the existing weight
-- MAGIC - Inserts new beans only if they are delicious

-- COMMAND ----------

-- ANSWER
MERGE INTO beans a
USING new_beans b
ON a.name=b.name AND a.color = b.color
WHEN MATCHED THEN
  UPDATE SET grams = a.grams + b.grams
WHEN NOT MATCHED AND b.delicious = true THEN
  INSERT *

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Run the cell below to check your work.

-- COMMAND ----------

-- MAGIC %python
-- MAGIC version = spark.sql("DESCRIBE HISTORY beans").selectExpr("max(version)").first()[0]
-- MAGIC last_tx = spark.sql("DESCRIBE HISTORY beans").filter(f"version={version}")
-- MAGIC assert last_tx.select("operation").first()[0] == "MERGE", "Transaction should be completed as a merge"
-- MAGIC metrics = last_tx.select("operationMetrics").first()[0]
-- MAGIC assert metrics["numOutputRows"] == "3", "Make sure you only insert delicious beans"
-- MAGIC assert metrics["numTargetRowsUpdated"] == "1", "Make sure you match on name and color"
-- MAGIC assert metrics["numTargetRowsInserted"] == "2", "Make sure you insert newly collected beans"
-- MAGIC assert metrics["numTargetRowsDeleted"] == "0", "No rows should be deleted by this operation"

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Review the Table History
-- MAGIC 
-- MAGIC Delta Lake's transaction log stores information about each transaction that modifies a table's contents or settings.
-- MAGIC 
-- MAGIC Review the history of the `beans` table below.

-- COMMAND ----------

-- ANSWER
DESCRIBE HISTORY beans

-- COMMAND ----------

-- MAGIC %md
-- MAGIC If all the previous operations were completed as described you should see 7 versions of the table (**NOTE**: Delta Lake versioning starts with 0, so the max version number will be 6).
-- MAGIC 
-- MAGIC The operations should be as follows:
-- MAGIC 
-- MAGIC | version | operation |
-- MAGIC | --- | --- |
-- MAGIC | 0 | CREATE TABLE |
-- MAGIC | 1 | WRITE |
-- MAGIC | 2 | WRITE |
-- MAGIC | 3 | UPDATE |
-- MAGIC | 4 | UPDATE |
-- MAGIC | 5 | DELETE |
-- MAGIC | 6 | MERGE |
-- MAGIC 
-- MAGIC The `operationsParameters` column will let you review predicates used for updates, deletes, and merges. The `operationMetrics` column indicates how many rows and files are added in each operation.
-- MAGIC 
-- MAGIC Spend some time reviewing the Delta Lake history to understand which table version matches with a given transaction.
-- MAGIC 
-- MAGIC **NOTE**: The `version` column designates the state of a table once a given transaction completes. The `readVersion` column indicates the version of the table an operation executed against. In this simple demo (with no concurrent transactions), this relationship should always increment by 1.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Query a Specific Version
-- MAGIC 
-- MAGIC After reviewing the table history, you decide you want to view the state of your table after your very first data was inserted.
-- MAGIC 
-- MAGIC Run the query below to see this.

-- COMMAND ----------

SELECT * FROM beans VERSION AS OF 1

-- COMMAND ----------

-- MAGIC %md
-- MAGIC And now review the current state of your data.

-- COMMAND ----------

SELECT * FROM beans

-- COMMAND ----------

-- MAGIC %md
-- MAGIC You want to review the weights of your beans before you deleted any records.
-- MAGIC 
-- MAGIC Fill in the query below to register and query a temporary view of the version just before data was deleted.

-- COMMAND ----------

-- ANSWER
CREATE OR REPLACE TEMP VIEW pre_delete_vw AS
  SELECT * FROM beans VERSION AS OF 4;

SELECT * FROM pre_delete_vw

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Run the cell below to check that you have captured the correct version.

-- COMMAND ----------

-- MAGIC %python
-- MAGIC assert spark.table("pre_delete_vw"), "Make sure you have registered the temporary view with the provided name `pre_delete_vw`"
-- MAGIC assert spark.table("pre_delete_vw").count() == 6, "Make sure you're querying a version of the table with 6 records"
-- MAGIC assert spark.table("pre_delete_vw").selectExpr("int(sum(grams))").first()[0] == 43220, "Make sure you query the version of the table after updates were applied"

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Restore a Previous Version
-- MAGIC 
-- MAGIC Apparently there was a misunderstanding; the beans your friend gave you that you merged into your collection were not intended for you to keep.
-- MAGIC 
-- MAGIC Revert your table to the version before this `MERGE` statement completed.

-- COMMAND ----------

-- ANSWER
RESTORE TABLE beans TO VERSION AS OF 5

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Review the history of your table. Make note of the fact that restoring to a previous version adds another table version.

-- COMMAND ----------

DESCRIBE HISTORY beans

-- COMMAND ----------

-- MAGIC %python
-- MAGIC last_tx = spark.conf.get("spark.databricks.delta.lastCommitVersionInSession")
-- MAGIC assert spark.sql(f"DESCRIBE HISTORY beans").select("operation").first()[0] == "RESTORE", "Make sure you reverted your table with the `RESTORE` keyword"
-- MAGIC assert spark.table("beans").count() == 5, "Make sure you reverted to the version after deleting records but before merging"

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## File Compaction
-- MAGIC Looking at the transaction metrics during your reversion, you are surprised you have some many files for such a small collection of data.
-- MAGIC 
-- MAGIC While indexing on a table of this size is unlikely to improve performance, you decide to add a Z-order index on the `name` field in anticipation of your bean collection growing exponentially over time.
-- MAGIC 
-- MAGIC Use the cell below to perform file compaction and Z-order indexing.

-- COMMAND ----------

-- ANSWER
OPTIMIZE beans
ZORDER BY name

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Your data should have been compacted to a single file; confirm this manually by running the following cell.

-- COMMAND ----------

DESCRIBE DETAIL beans

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Run the cell below to check that you've successfully optimized and indexed your table.

-- COMMAND ----------

-- MAGIC %python
-- MAGIC last_tx = spark.sql("DESCRIBE HISTORY beans").first()
-- MAGIC assert last_tx["operation"] == "OPTIMIZE", "Make sure you used the `OPTIMIZE` command to perform file compaction"
-- MAGIC assert last_tx["operationParameters"]["zOrderBy"] == '["name"]', "Use `ZORDER BY name` with your optimize command to index your table"

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Cleaning Up Stale Data Files
-- MAGIC 
-- MAGIC You know that while all your data now resides in 1 data file, the data files from previous versions of your table are still being stored alongside this. You wish to remove these files and remove access to previous versions of the table by running `VACUUM` on the table.
-- MAGIC 
-- MAGIC Executing `VACUUM` performs garbage cleanup on the table directory. By default, a retention threshold of 7 days will be enforced.
-- MAGIC 
-- MAGIC The cell below modifies some Spark configurations. The first command overrides the retention threshold check to allow us to demonstrate permanent removal of data. 
-- MAGIC 
-- MAGIC **NOTE**: Vacuuming a production table with a short retention can lead to data corruption and/or failure of long-running queries. This is for demonstration purposes only and extreme caution should be used when disabling this setting.
-- MAGIC 
-- MAGIC The second command sets `spark.databricks.delta.vacuum.logging.enabled` to `true` to ensures that the `VACUUM` operation is recorded in the transaction log.
-- MAGIC 
-- MAGIC **NOTE**: Because of slight differences in storage protocols on various clouds, logging `VACUUM` commands is not on by default for some clouds as of DBR 9.1.

-- COMMAND ----------

SET spark.databricks.delta.retentionDurationCheck.enabled = false;
SET spark.databricks.delta.vacuum.logging.enabled = true;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Before permanently deleting data files, review them manually using the `DRY RUN` command.

-- COMMAND ----------

VACUUM beans RETAIN 0 HOURS DRY RUN

-- COMMAND ----------

-- MAGIC %md
-- MAGIC All data files not in the current version of the table will be shown in the preview above.
-- MAGIC 
-- MAGIC Run the command again without `DRY RUN` to permanently delete these files.
-- MAGIC 
-- MAGIC **NOTE**: All previous versions of the table will no longer be accessible.

-- COMMAND ----------

VACUUM beans RETAIN 0 HOURS

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Because `VACUUM` can be such a destructive act for important datasets, it's always a good idea to turn the retention duration check back on. Run the cell below to reactive this setting.

-- COMMAND ----------

SET spark.databricks.delta.retentionDurationCheck.enabled = true

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Note that the table history will indicate the user that completed the `VACUUM` operation, the number of files deleted, and log that the retention check was disabled during this operation.

-- COMMAND ----------

DESCRIBE HISTORY beans

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Query your table again to confirm you still have access to the current version.

-- COMMAND ----------

SELECT * FROM beans

-- COMMAND ----------

-- MAGIC %md
-- MAGIC Note that because Delta Cache stores copies of files queried in the current session on storage volumes deployed to your currently active cluster, you may still be able to temporarily access previous table versions (though systems should **not** be designed to expect this behavior). Restarting the cluster will ensure that these cached data files are permanently purged.

-- COMMAND ----------

SELECT * FROM beans@v1

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Wrapping Up
-- MAGIC 
-- MAGIC Run the following cell to remove the database and all data associated with this lab.

-- COMMAND ----------

-- MAGIC %run ../Includes/sql-setup $course="delta" $mode="cleanup"

-- COMMAND ----------

-- MAGIC %md
-- MAGIC By completing this lab, you should now feel comfortable:
-- MAGIC * Completing standard Delta Lake table creation and data manipulation commands
-- MAGIC * Reviewing table metadata including table history
-- MAGIC * Leverage Delta Lake versioning for snapshot queries and rollbacks
-- MAGIC * Compacting small files and indexing tables
-- MAGIC * Using `VACUUM` to review files marked for deletion and committing these deletes

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC &copy; 2022 Databricks, Inc. All rights reserved.<br/>
-- MAGIC Apache, Apache Spark, Spark and the Spark logo are trademarks of the <a href="https://www.apache.org/">Apache Software Foundation</a>.<br/>
-- MAGIC <br/>
-- MAGIC <a href="https://databricks.com/privacy-policy">Privacy Policy</a> | <a href="https://databricks.com/terms-of-use">Terms of Use</a> | <a href="https://help.databricks.com/">Support</a>