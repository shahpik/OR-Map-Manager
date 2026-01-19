# OSM Ingestion Step Function Walkthrough

Below is the transcript of the meeting with Cody and attached is the step function he was showing me for ingesting OSM data.

---

## Transcript

### Repository Structure

**Cody:** It's kind of weird how everything's laid out. Basically, everything used to be in this big OR rate mode, but since then, everything has been separated out into separate repos. So, we're gonna be looking at the contents of both of them.

There were still a few things that were separated out, like these two, for example, were separated out of the main repo.

**Me:** Are they separated out as some specific components?

**Cody:** So all of the microservices were contained in a mono repo, but they have since been moved out. So each service has its own repo now, but there were already some external repos that were used for various things.

This one, for example, OR MM ETL workflow, was used for defining the step function definitions. So in here, the Delta OSM file defines the step function in Terraform template format for the source ingestion of OSM.

---

### OSM Ingestion Process Overview

**Cody:** So whenever there's a... remember how I said there's a fortnightly update of OSM? This is the process that runs. It is 3000 lines long, so it's a little bit complicated to go through, but basically it starts from create change set, and then it works its way down. The step functions call functions within the microservices directly.

**Me:** Could you do a walkthrough from an entry perspective? Like, how does a change in OSM make its journey from OSM into the system?

**Cody:** The very start would be that a person makes the change in OSM and then when the trigger happens - there's an AWS scheduling service that gets used and it calls the step function every fortnight. I can't remember exactly when, but I think it's like Thursday, 2 AM or something like that.

---

### High-Level Application Architecture

**Me:** Maybe we should take one step back. Can you give me a high level idea of the application architecture? Like, these 2 source systems - the data from that is ingested into what database? What exactly is that database? Is that Postgres?

**Cody:** Yes.

**Me:** Is there any structure to that? Any layers?

**Cody:** At an extremely high level:
1. Changes get written into the Map Manager database (there's only one database)
2. Data gets written into some temporary tables (temporary in the sense that they eventually get deleted, not actually temporary tables)
3. A bunch of processing happens where matching happens, the algorithm gets applied
4. Then a stage happens where it polls continuously waiting until DTP clicks a button in the front end saying "approve"
5. Once that happens, all the changes that are approved/rejected get saved from those temporary tables into the permanent tables
6. They get updated so that they're actually part of a new version of the network
7. Persistence happens in that step as well
8. At the very end, it gets pushed to LRS (Location Reference Service), which is the API that serves all the other downstream consumers of the DTP network

---

### LRS and Downstream Consumers

**Me:** Is LRS the only consumption downstream?

**Cody:** LRS is the only output of Map Manager, but there are many outputs from LRS. LRS gets used for GRID (the road accident database). I don't think it gets used by SA, but there are also other external things that use LRS.

**Me:** But Map Manager finishes once it serves LRS, right?

**Cody:** Yes, that's correct.

---

### Step-by-Step Process Walkthrough

#### Step 1: Create Change Set

**Cody:** In the database, we have a lot of tables, one of which is change set. The idea is that a change set should encompass a whole bunch of updates to the network, and then it can separately be approved by someone with the correct permissions. When they click approved, it gets saved as a version of the network and all the features and attribute changes get solidified into the correct tables and then get served by LRS.

So that's what we're doing in the very first step - we're setting up that change set for all of these source updates to be put inside of.

**Me:** This is all through Microservices, right?

**Cody:** Yes, there's like 4 different microservices that encompass Map Manager and then another 3 or so that encompass LRS. That one happens within Map Editor.

#### Step 2: Truncate Temporary Tables

**Cody:** The next step is truncating those temporary tables.

#### Step 3: Ingest Data

**Cody:** The next step is ingesting data - that's literally just API calls to the OSM or VicMap API to download changes.

#### Step 4: Calculate Delta

**Cody:** This step actually looks at the data that's been ingested versus our current network to find what is different, so we can only focus on the things that have changed. Everything that hasn't changed is basically just left as is.

#### Step 5: Refresh Fee Table

**Cody:** That's just refreshing a materialised view, I think.

#### Step 6: Update Change Set Status

**Cody:** In the change set table, there is a column called status, which in the front end shows what step in the ingestion process we're at.

#### Step 7: Check Change Set Status (First Approval)

**Cody:** This is the approval step. This is where we're waiting until the front end button gets clicked by DTP. When that button gets clicked, it sets a value in the database and sets the status to "approved" or something, and that's when it can move on to the next step.

**Important Note:** This step is the one I mentioned in today's meeting - the one that's a little bit funny because step functions have a limit of like 20,000 events. Every time it goes through this, it runs like 5 events. It polls every 2 minutes or something to see whether the status is updated, but if it runs for too long, then we meet the limit of the step function, which means everything else after it doesn't run.

**Me:** But that's not one of the issues they have highlighted anyway, right?

**Cody:** It's not an issue that they've highlighted, but it is an issue that has come up a lot in the past. It's related to the "within 24 hours" requirement and also the requirements around having everything within the 2 weeks update.

#### Step 8: Source Update Publish Change Set

**Cody:** This is run to move things from the temporary tables into the actual permanent tables for features and attributes.

#### Step 9: Update Change Set Status Post-Approval

**Cody:** Just updating the status so that it doesn't say approved anymore and says something after that.

#### Step 10: Refresh Materialised View (Feed Table Pro Published)

**Cody:** This refreshes the materialised table view that gets used by the GraphQL API, which is used by the front end to display features and attributes in the front end map. That's eventually used so that DTP employees can look at the changes to decide whether they want them or not.

#### Step 11: Run Matching

**Cody:** Just running the matching algorithm.

**Me:** So that's where the algorithm is triggered, right? The main algorithm?

**Cody:** Yes.

**Me:** How long is that taking?

**Cody:** I can't remember exactly. There's a step later on - delta persistence - that takes a lot longer. But I think this one's within a day or two. Once we've got access, we can check the logs to see specifically how long that one runs for.

#### Step 12: Invalidate Previous OSM Relationships

**Cody:** Any of the new updates that override relationships that were already used before - the old ones need to be invalidated so they're no longer considered and the new ones aren't competing.

#### Step 13: Truncate All Time Tables

**Cody:** Just truncating the tables.

#### Step 14: Create Derived Layer

**Cody:** Creating a new layer in the MM derived feature table, rather than the MM feature.

#### Step 15: Copy Unbroken OSM Data

**Cody:** Just copying data from MM feature to derived feature.

#### Step 16: Delta Persistence

**Cody:** This is a big one. This runs all of the persistence logic, which is itself like 12 steps within it. I think there's a diagram in the Confluence docs that explains it better. It's the step that basically tries to look at the matching results and work out whether we should move attributes from an old removed feature to an added feature.

**Me:** When we go back, the data persists - like the rules, the decisions based on which we take action - have you finalised those together with DTP?

**Cody:** All the decisions were made with DTP. Everything - this entire process was approved by DTP and they were very involved in the process of making this.

#### Step 17: Refresh DTP Feature Materialised View

**Cody:** Refreshing the materialised view again. There are multiple materialised views used for different things.

#### Step 18: Run Matching Against Derived Layer

**Cody:** This one is running the map matching algorithm again, but this time between the derived layer and the original OSM assembly.

**Me:** How is it different? The network is already calculated when we trigger the initial algorithm with the new data.

**Cody:** When it gets first called above, the derived network hasn't been worked out yet. A lot of this already existed when I was first joining. I mostly joined for adding this step and some of the stuff below. Different layers are getting matched against each other. At a high level, I would presume that's because the algorithm isn't exactly designed for this use case, which is why it's a little bit messy.

#### Step 19: Invalidate Previous DTP Relationships

**Cody:** Similar to the one above where we're invalidating the relationships, but this time in the derived network, not the OSM network.

#### Step 20: Refresh DTP Relationships Materialised View

**Cody:** Refreshing a materialised view that gets used in the front end for working out which attributes to show for a particular DTP feature, because the attributes are coming from the related VicMap feature.

#### Step 21: Generate Match Reports

**Cody:** Generating a report that gets displayed in the front end.

**Me:** That's the one we saw yesterday?

**Cody:** No, this is a little bit different. This is a very high level report. The report they're talking about in the requirements document is a separate JSON file that I created so we could communicate with DTP about the persistence process. This generates a report saved in the database - basically saving the overall match quality of that update.

**Me:** These reports are in the front end?

**Cody:** Yes, these are visible in the front end. They are a little bit broken because one of the changes we made was we needed to increase the bounding box of Victoria, but we couldn't do that for VicMap - only for OSM. So the match percentage is much lower than it used to be. I don't think they actually look at it, to be honest.

#### Step 22: Export to S3

**Cody:** The data in the derived network (the derived feature table, derived attributes, and relationships) gets turned into a GeoJSON format or an OSM format. It gets turned into a format that's saved in S3. That is the file that gets read by LRS as well as the intersection stuff.

#### Step 23: Run Calculate Intersections

**Cody:** This step calculates intersections. It looks at the roads and road names and tries to work out whether that's an intersection or not.

**Me:** I thought that would be done before the export. Logically speaking, shouldn't this be before they export? Or is this not required by LRS?

**Cody:** LRS does use intersection information, but it uses it in a different way. Intersections are a very funny thing - they don't interact with LRS in the same way as features and attributes. I think it's possibly because this microservice uses the S3 file rather than the database directly. It uses a dependent library which creates an OSM graph from the OSM network file. That's why I think this has to happen first - otherwise, we'd be doing duplicate work.

#### Step 24: Refresh Intersections Materialised View

**Cody:** This refreshes the materialised view in the database that gets used by the GraphQL API for the front end map.

**And that's the process.**

---

### Post-Process: LRS Update

**Cody:** Oh, I think there is actually one more thing that happens after this, but it's not a step here. It gets called directly later, where it calls something in LRS to reconstruct the Tile38 database, which basically tells it to read the file and read the features into a database that is separate from the Map Manager database.

---

## The Matching Algorithm

**Me:** The algorithm - is that a standalone Python application which is being called here through the microservice, or is it a set of SQLs?

**Cody:** It's Julia. Written by Deloitte, not a third-party library.

**Me:** Can I get access?

**Cody:** It's in a separate repo - ORSDK. There's a module called `SpatialUtilities.jl`, and in here it calls functions. Any questions about the matching algorithm would be answered there.

**Cody:** You're best not asking me about it because it was all very much before I got here. Aaron, who did understand it, came in when it was already in development. There should be documentation somewhere for it.

**Me:** I hope there's good documentation because we don't have too much time.

**Cody:** To be honest, I don't think most of this should be super necessary if we were to redesign a better algorithm for our use case, because a lot of this was designed specifically for limitations with matching VicMap to OSM, which we're not doing anymore.

---

## Architecture Discussion

**Me:** When you say we are not doing it anymore, it confuses me. We are doing it continuously, right?

**Cody:** No, the original algorithm was designed to match OSM with VicMap. But now we have a 3rd network - our derived network. What we're trying to do is match OSM to that derived network, or more aptly, match updates to OSM to our new network, as well as updates to the VicMap network.

**Me:** So what we're doing now is: the derived network that we've created - we match it with OSM for changes. And the attributes of VicMap are actually mapped to the derived network rather than OSM network?

**Cody:** Yes, because we only care about the derived network. We only want to take those changes to the 2 source networks and pull them into our derived network. A lot of the logic from the map matching algorithm was designed to be focused on OSM to VicMap. Because we've got that derived network in between, I don't think it's the end of the world if we cut out some of the stuff from this algorithm.

**Me:** And do some of the things in database, right?

**Cody:** Oh yeah, exactly, because that will make things so much faster.

---

## Performance Optimization Discussion

**Me:** In my initial discussion with Frederick, he was identifying that there was a lot of data to and fro between the source and Map Manager or the front end and back end. He wanted to highlight that we should look at whether that can be optimised. Does that ring a bell?

**Cody:** Yes. The reason for that is because of the Julia algorithm. The inputs for that function require all of the information to basically be downloaded from the database and then in memory in the microservice as it's running the matching. Then it gets the output and does processing on that in Julia before it gets saved to the database.

That's what he's talking about. The reason is because of how the algorithm was originally designed and how it's currently being used. There is almost certainly room for improvement because most of the stuff should probably just be happening in the database using SQL transformations, not pulling it into Julia, doing the transformations there, and then pushing it back to the database.

---

## Julia Code Structure

**Cody:** In ORSDK, there's this module called `SpatialUtilities.jl`. In the actual matcher code, it calls within app this function. It runs functions in `persistence.jl` that do all the persistence logic. But the actual matching logic is in a separate repo that gets imported.

**Cody:** It's a Julia function that was created very early on in the Map Manager project because originally all this persistence stuff didn't exist. It was just going to be a one-time matching of VicMap against OSM, but then they decided to add all the editing stuff on top of it and they needed the persistence. That's kind of an explanation for why it's kind of a mess.

---

## Database Documentation

**Me:** Do we have access to the database or documentation on the database, like the tables, the structures?

**Cody:** As far as I'm aware, there is no documentation on the database, unfortunately. There wasn't any when I joined and Aaron had to basically explain everything to me as best he could. As for access to the database, we're going to have to do a bunch of stuff with the DevOps team.

**Me:** I'll try to avoid it as much as possible, unless necessary.

**Cody:** I personally don't think they're going to go for that until work actually gets paid for by DTP. But I might be able to construct a poor man's schema of the database for you if you'd like.

**Me:** Yes, that'll be good. It doesn't have to be 100% accurate, but to get an idea.

**Cody:** I'll do my best.

---

## Step Functions Architecture Discussion

**Me:** I know your observation around getting rid of the step functions, but how will we justify why we came up with step functions in the first place?

**Cody:** The original use case for step functions was because they were trying to reduce cost of not having a continuously running service. But we already do because Map Editor is always running with at least one pod for things happening in the front end. In that case, why not just have HTTP endpoints instead?

This Terraform file shows you just how chaotic this step function is. If you were able to see it in the AWS console, you would probably question everything. There are things going everywhere.

It also has the unfortunate consequence that if we want to introduce new processes, we need to introduce whole new step functions. All the code has been written very designed for this step function process, which means that if you want a new process, you're going to have to heavily change the code and the step functions because it's all kind of entwined.

Whereas if you had more modular API endpoints just to call for various actions, that would make it a lot more composable.

**Me:** For example, if they have to call one microservice within this due to a certain business function, they have to create a separate step function?

**Cody:** It depends on what you're trying to achieve. If you're trying to do something very similar to this process but slightly different, you need to create a whole brand new step function.

For example, this step function is just for OSM source updates. If you want the VicMap updates, that's a whole other step function that looks almost identical, but it's not the same because various inputs have to be different, and a few steps don't happen for VicMap but do happen for OSM, and vice versa.

So these two are basically the same, but they had to be created separately because they are slightly different.

---

## Closing

**Me:** That's good enough for now. Let me digest this and get my access to this code. I can brainstorm a few ideas with you next week.

**Cody:** Awesome. Cool.

**Me:** Thank you, and have a good weekend.

**Cody:** You too. See you next week. Bye.
