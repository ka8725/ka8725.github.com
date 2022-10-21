---
layout: post
title: "Move 35Gb files from DB to AWS S3"
modified: 2022-10-05 00:41:06 +0300
description: "A practical example of how to move large amount of files from DB to AWS S3."
tags: [ruby, aws, s3]
comments: true
share: true
---

From the beginning, a Rails application stored uploaded files inside PostgreSQL DB using
[refile](https://github.com/refile/refile) gem with the [refile-postgres](https://github.com/krists/refile-postgres) addition.
The DB dump has been steadily growing. After 5 years, its size has become 35 Gb.
It's too much for the Heroku hosting to make full dumps.
The DB analysis shows that the dump is occupied 99% by "large objects".
These are the files.

To eliminate the issue, we are going to store the files in AWS S3 cloud storage.
We implemented an adapter that understands where to read the files from and where to write so that the application
supports the previously uploaded files. The new files are being written into AWS S3 directly, and the dump is not growing anymore so fast.

Not bad so far, but the issue is still there - the dump is still too big.
We need to move the files from DB to AWS S3. There are 50000 files with a total size of 34 Gb.
That's too much and a rough estimate shows that the copy operation would take 5 hours.
Easy calculations show that splitting the operation into 5 parallel threads would take 1 hour.

Sliced the files into batches, we can open 5 tabs in the terminal and run the commands to process each batch:

```bash
tab1$ heroku run BATCH=1 MAX_BATCHES=5 rake copy_attachments_to_s3
tab2$ heroku run BATCH=2 MAX_BATCHES=5 rake copy_attachments_to_s3
tab3$ heroku run BATCH=3 MAX_BATCHES=5 rake copy_attachments_to_s3
tab4$ heroku run BATCH=4 MAX_BATCHES=5 rake copy_attachments_to_s3
tab5$ heroku run BATCH=5 MAX_BATCHES=5 rake copy_attachments_to_s3
```

Surprisingly, several batches finished too fast but the number of copied files was not increased proportionally as expected.
Unfortunately, the code suppresses all exceptions. This doesn't give any clue why it could happen.
After several tries and some experiments with the batch number variations, it's getting clear that AWS is not ready for 5 threads.
Even 2 threads didn't add too much speed boost. We conclude that it's better to run everything in one thread and call it a day:

```bash
tab1$ heroku run BATCH=1 MAX_BATCHES=1 rake copy_attachments_to_s3
```

If you don't want to keep the terminal open it's better to run one-off Heroku dyno:

```bash
tab1$ heroku run:detached BATCH=1 MAX_BATCHES=1 rake copy_attachments_to_s3
```

Finally, all files were copied to S3 and we are ready to clean our DB. The whole migration took 5 hours.

Stopping and running scripts again could cause duplicated files copied to S3.
So, in the end, a Python script checked if there are no duplicated files.
The script was stolen somewhere from the Internet and was slightly modified.
It's not in Ruby because it was faster to get something ready rather than write it from scratch.

### Takeaways

- Storing files within DB is not a bad approach for a start, but be prepared for the future.
- There is no point in parallel files copying to AWS S3.
- A detached process can be run on Heroku in background.
- Copying 35 Gb of data to S3 roughly takes 5 hours.

### Attachments

The script to copy files to S3:

<br />

<script src="https://gist.github.com/ka8725/2769f5f535ed06b98e1eb800472a256b.js"></script>


The refile gem adapter that allows switching between S3 and DB storage:

<br />

<script src="https://gist.github.com/ka8725/633b50d5e881c32cd4238493e9f44064.js"></script>

The Python script to check if there are no duplicated files:

<br />

<script src="https://gist.github.com/ka8725/6108daa7f59d3e67418ca0da691f9ed5.js"></script>
