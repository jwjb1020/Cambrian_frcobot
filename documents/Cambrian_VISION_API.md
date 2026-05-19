Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

## Home / Cambrian VISION 

Use with AI 

2.3 

## ~~Cambrian VISION API~~ 

The Cambrian Vision UI implements a TCP/IP socket server. 

This server listens for requests from an external device (usually the robot) and replies with the relevant data. 

This API is normally used within specific Robot APIs. 

There are multiple possible requests to help build different tasks. 

## Command Structure 

The requests must be a string with the following structure: 

## **COMMAND TYPE** # **INPUT DATA** # **FLANGE POSE** # **JOINTS VALUES** # **TOOL OFFSET** #<< 

Note the “#” separating each field, and the “#<<“ sequence marking the end of the message. 

- **COMMAND TYPE** → a string identifying the type of request/command being sent 

- **INPUT DATA** → depends on the request but will be some form of a “#” and “,” separated list of values, specific request information is listed below 

- **FLANGE POSE →** comma separated list of values indicating the current Cartesian pose of the robot flange 

- **JOINTS VALUES** → comma separated list of values indicating the joints angles of the robot. This is only required for robots with visual robot representation in the UI 

- **TOOL OFFSET** → comma separated list of values indicating the current robot tool definition 

## Reply Structure 

On success, the Cambrian Vision UI replies with a message of the following structure: 

## << **TEXT MESSAGE** >> << **RETURN CODE** >> << **DATA** >> 

Note the “<<“ and “>>” encapsulating each field. 

- **TEXT MESSAGE** → usually “OK” on success, some other information or error information when needed 

- **RETURN CODE** → numeric code indicating the type of reply: 

   - **0** → **OR** → the request was processed successfully 

   - **1** → **ERROR** → the request was **not successful** . In this instance **the robot program should stop** and the TEXT MESSAGE should be printed to inform the user 

   - **2** → **WARNING** → the request might be **successful or not** . The **robot program should not be stopped** but TEXT MESSAGE should be printed to inform the user 

   - **3** → **PRINT** → the request was **successful** but TEXT MESSAGE should be printed anyways. 

- **DATA →** depends on the request but will be some form of a “#” and “,” separated list of values, specific request information is listed below 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

1/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

## Commands 

## Cameras Calibration Commands 

## **Command String** 

```
CAPTURE CALIBRATION IMAGE
```

## **Input Data** 

none 

## **Output Data** 

none 

This command is used when performing manual calibration. 

It captures an image and tries to detect the calibration board. 

This command is only valid if a `START CALIBRATION` command has been executed before. 

## **Command String** 

```
SET CALIBRATION RIG POSE
```

## **Input Data** 

rig pose → csv pose 

focal length (in mm)→ float 

or 

rig pose → csv pose focal length (in mm)→ float stereo separation (in m) → float camera tilt (in degrees) → float 

## **Input Data Format** 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

2/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

csv_pose*focal_length 

or 

csv_pose*focal_length*stereo_separation*camera_tilt 

## **Output Data** 

## none 

## Sets the rig parameters. 

This can be called called before `START CALIBRATION` to configure the rig. The same information can be provided directly to `START CALIBRATION` instead. 

Focal length is determined by the cameras currently mounted on the camera rig. Stereo separation is the distance, in meters, between the left and right cameras. 

Camera tilt is how much each camera is tilted towards the centre of the camera rig, in degrees. 

|**Rig Model**|**Focal Length**|**Stereo Separation**|**Camera Tilt**|
|---|---|---|---|
|standard|8|0.08|5|
|small|8|0.06|8|



If you’re using a customised camera rig you’ll need to configure these values accordingly. 

Contact our support team for information regarding your specific setup if needed. 

Different camera interfaces might implement different units for the stereo separation value (for example, providing the stereo separation in mm). 

Check the specific robot API documentation for more information. 

## **Command String** 

```
START CALIBRATION
```

## **Input Data** 

rig pose → csv pose 

focal length (in mm)→ float 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

3/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

or 

rig pose → csv pose 

- focal length (in mm)→ float stereo separation (in m) → float 

camera tilt (in degrees) → float 

## **Input Data Format** 

csv_pose*focal_length 

or 

csv_pose*focal_length*stereo_separation*camera_tilt 

## **Output Data** 

## none 

Initiates a new calibration. 

This creates the new folders and spawns the required processes. 

This command is necessary for both automatic calibration and manual calibration. 

Check the command above ( `SET CALIBRATION RIG POSE` ) for more information on the rig parameters. 

## **Automatic calibration** 

For automatic calibration these values should be a rough approximation of the pose of the rig relative to the robot flange. 

This is used for estimating good poses for image capture. 

Check `NEXT CALIBRATION STEP` for more info on automatic calibration. 

## **When doing manual calibration** 

For manual calibration the rig pose can be defined as 0,0,0,0,0,0 without any impact. 

After this, multiple `CAPTURE CALIBRATION IMAGE` commands should be called, from different positions overlooking the calibration board. In the end, the manual calibration procedure should be triggered from the Cambrian VISION UI. 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

4/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**==> picture [292 x 313] intentionally omitted <==**

## **Command String** 

```
NEXT CALIBRATION STEP
```

## **Input Data** 

none 

## **Output Data** 

calibration_step,x,y,z,a,b,g, 

This command is only valid when called after a `START CALIBRATION` command has been sent. 

For automatic calibration, this command can be used to query the Cambrian UI on what action to take next. 

This should be run in a loop until the calibration process is finished, at which point, the robot program should terminate. 

The returned `calibration_step` variable should be used to perform different actions. 

The subsequent `x,y,z,a,b,g` represent a pose that the robot should either test or move to. 

Automatic calibration robot pseudo-code: 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

5/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

Python 

|5/26, 1:59 PM<br>Cambrian VISION API | Cambrian VISION Documentation|5/26, 1:59 PM<br>Cambrian VISION API | Cambrian VISION Documentation|
|---|---|
|Python||
|`def cambrian_calibration(x, y, z, a, b, g, focal_length, stereo_separation, tilt):`<br> `# build the required data to send along with the request`<br>`data_string+= x.tostring() + ","`<br>`data_string+= y.tostring() + ","`<br>`data_string+= z.tostring() + ","`<br>`data_string+= a.tostring() + ","`<br>`data_string+= b.tostring() + ","`<br>`data_string+= g.tostring() + "*"`<br>`data_string+= focal_length.tostring() + "*"`<br>`data_string+= stereo_separation.tostring() + "*"`<br>`data_string+= tilt.tostring()`<br> `# instruct the UI to initiate the calibration`<br>`cambrian_send_request("START CALIBRATION", data_string)`<br> `# at this point, it's important to verify that the cameras, in the Cambrian UI, show up in the same pose as the real came`<br> `# if this is not true, the value of x,y,z,a,b,g must be adjusted accordingly`<br> `# reset the contents of the data_string`<br>`data_string= ""`<br> `while True:`<br> `# add a 1 second pause so the Cambrian UI is not spammed with requests`<br>`sleep(1)`<br> `# send a request with the additional data_string`<br>`reply= cambrian_send_request("NEXT CALIBRATION STEP", data_string)`<br> `# the next step is dictated by the first value in the returned array`<br>`next_step= reply[0]`<br> `if next_step== 1:`<br> `# next step being 1 means the Cambrian UI needs the robot to move to the given pose`<br> `# move the robot to the pose defined by the received x,y,z,a,b,g values`<br>`move_j(reply[1], reply[2], reply[3], reply[4], reply[5], reply[6])`<br> `else if next_step== 2:`<br> `# this means the calibration process has finished, the program should terminate`<br>`exit`<br> `else if next_step== 3:`<br> `# next step being 3 means the Cambrian UI needs to test the reachability of the received pose`<br> `if is_pose_reachable(reply[1], reply[2], reply[3], reply[4], reply[5], reply[6]):`<br>`data_string= "1"`<br> `else`<br>`data_string= "2"`<br>`1`<br>`2`<br>`3`<br>`4`<br>`5`<br>`6`<br>`7`<br>`8`<br>`9`<br>`10`<br>`11`<br>`12`<br>`13`<br>`14`<br>`15`<br>`16`<br>`17`<br>`18`<br>`19`<br>`20`<br>`21`<br>`22`<br>`23`<br>`24`<br>`25`<br>`26`<br>`27`<br>`28`<br>`29`<br>`30`<br>`31`<br>`32`<br>`33`<br>`34`<br>`35`<br>`36`<br>`37`<br>`38`<br>`39`<br>`40`<br>`41`<br>`42`<br>`43`<br>`44`||
|||



## **Command String** 

```
SET CALIBRATION MOUNT
```

## **Input Data** 

space → BASE or FLANGE 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

6/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Output Data** 

none 

Set the calibration to be performed to Fixed Mounted (BASE) or Robot Mounted (FLANGE). 

## **Command String** 

```
RUN MANUAL CALIBRATION
```

## **Input Data** 

none 

## **Output Data** 

none 

Begin the calibration procedure using calibration images previously captured by calling `CAPTURE CALIBRATION IMAGE` . 

It is required to have captured at least 8 images of the calibration target from different positions before running the `RUN MANUAL CALIBRATION` command. 

## Camera Commands 

## **Command String** 

```
CAMERAS AUTO
```

## **Input Data** 

none 

## **Output Data** 

none 

Sets camera exposure mode to Auto. 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

7/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

## **Command String** 

```
CAMERAS MANUAL
```

## **Input Data** 

none 

## **Output Data** 

none 

Sets camera exposure mode to Manual. 

## **Command String** 

## `CAMERAS AUTO PARAMS` 

## **Input Data** 

target → integer (5 to 255) 

tolerance → integer (1 to 250) 

max_iterations → integer (1 to 10) 

max_exposure → float 

## **Input Data Format** 

target*tolerance*max_iterations*max_exposure 

## **Output Data** 

none 

Sets parameters related to auto exposure algorithm. 

The auto exposure algorithm dynamically adjusts the camera exposure to keep the brightness at the target level. 

The sensitivity of the algorithm is dictated by the tolerance value. 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

8/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

Let’s imagine the algorithm is configured with: 

target → 100 tolerance → 10 max_iterations → 3 max_exposure → 500 

## **Example 1** 

1. images are captured 

2. brightness is measured at 105 (withing 90 and 110) 

3. images are returned and algorithm ends 

## **Example 2** 

1. images are captured 

2. brightness is measured at 40 

3. exposure is increased 

4. images are captured again 

5. brightness is measured at 95 

6. images are returned and algorithm ends 

The max_iterations parameter determines how many times the algorithm can repeat until images are returned even if the brightness level isn’t within the tolerance. 

The exposure will be kept under the max_exposure value. 

Here’s a simplified pseudo-algorithm of what happens internally: 

**==> picture [524 x 212] intentionally omitted <==**

**----- Start of picture text -----**<br>
1 iteration = 0<br>2<br>3 do<br>4   if iteration == max_iterations:<br>5     exit<br>6<br>7   if new_expose > max_exposure:<br>8     exit<br>9<br>10   set_exposure(new_exposure)<br>11<br>12   images = capture_images(new_exposure)<br>13   new_exposure = calculate_new_exposure(images, target)<br>14<br>15   iteration += 1<br>16<br>17 while Abs(images.brightness - target) > tolerance<br>**----- End of picture text -----**<br>


## **Command String** 

```
CAMERAS EXPOSURE
```

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

9/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

## **Input Data** 

exposure → float 

## **Output Data** 

none 

Sets camera exposure. 

This only has effect if the cameras are running in manual exposure mode. 

## **Command String** 

```
CAMERAS GAIN
```

## **Input Data** 

gain → float 

## **Output Data** 

none 

Sets camera gain. 

Higher gain means brighter images but also more noise. 

For most models, running with maximum gain (and thus, maximum noise) does not cause issues. 

The value is clamped to the minimum and maximum values supported by the camera. 

To set the gain to the maximum supported simply send a very high value, for example, 999. 

## **Command String** 

```
CHECK CAMERAS
```

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

10/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM **Input Data** 

none 

## **Output Data** 

cameras connected → 1 

cameras not connected → 0 

Check if there’s an active camera connection. 

This command returns 1 if the cameras are connected and 0 if the cameras are not connected. 

## **Command String** 

```
RESTART CAMERAS
```

## **Input Data** 

none 

## **Output Data** 

none 

Restarts the camera server and connection. 

This command performs the same routine as clicking the refresh camera connection button in Cambrian VISION. 

## **Command String** 

## `WAIT CAMERAS` 

## **Input Data** 

none 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

11/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Output Data** 

none 

Waits for the camera connection to be established. 

If the camera connection fails or takes too long this command will timeout and throw an error. 

## **Command String** 

```
GET CAMERA AUTO
```

## **Input Data** 

none 

## **Output Data** 

Cameras in Auto exposure → 1 

Cameras in Manual exposure → 0 

Gets the cameras exposure mode. 

Return 1 for Auto and 0 for Manual 

## **Command String** 

```
GET CAMERA AUTO PARAMS
```

## **Input Data** 

none 

## **Output Data** 

target,tolerance,max_iterations,max_exposure 

target → integer (5 to 255) 

tolerance → integer (1 to 250) max_iterations → integer (1 to 10) max_exposure → float 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

12/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

Gets parameters related to auto exposure algorithm. 

See SET CAMERAS AUTO PARAMS for details. 

## **Command String** 

```
GET CAMERA EXPOSURE
```

## **Input Data** 

none 

## **Output Data** 

exposure → float 

Gets camera exposure. 

This only has effect if the cameras are running in manual exposure mode. 

## **Command String** 

```
GET CAMERA GAIN
```

## **Input Data** 

none 

## **Output Data** 

gain → float 

Gets camera gain. 

System Commands 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

13/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Command String** 

```
GET VERSION
```

## **Input Data** 

none 

## **Output Data** 

3 floats in major,minor,hotfix 

Gets the supported CambrianVision API version string. Returns 3 floats representing major, minor, hotfix versions. 

## **Command String** 

```
SET PREDICTION SPACE
```

## **Input Data** 

space description → string 

## **Output Data** 

none 

This sets the Coordinate system in which the Prediction commands should be returned. 

Acceptable Inputs are: “BASE“, “FLANGE“ 

## **Command String** 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

14/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM `CLEAR MEMORY` 

## **Input Data** 

none 

## **Output Data** 

none 

Delete all memory of previously seen parts. 

This essentially resets the state of smart search. 

## **Command String** 

```
GET ALL PREDICTIONS
```

## **Input Data** 

part name → string 

or 

part name → string 

grasp priority → csv integers 

or 

part name → string 

grasp priority → csv integers ignored grasps → csv integers 

or 

part name → string 

- grasp priority → csv integers ignored grasps → csv integers sorting type→ integer 

## **Input Data Format** 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

15/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

part_name 

or 

part_name*grasp_priority 

or 

part_name*grasp_priority*ignored_grasps 

or 

part_name*grasp_priority*ignored_grasps*sorting_type 

## **Output Data** 

list of values 

first value is the number of predictions, subsequent sets of 8 values represent individual predictions 

n_predictions,x,y,z,a,b,g,type,score,x,y,z,a,b,g,type,score,x,y… 

Captures images and runs the AI model requested. 

Returns all the predictions (up to 10) that do not cause collisions with the defined rig boxes. 

The predictions are packed into a single list of comma separated floats. 

Check `GET PREDICTION` for more details about priority, ignoring grasp types and sorting types. 

The first value of the returned list is the number of predictions in the list. 

This means the list has 1 + 8 * n_predictions comma separated values. 

The first value should be parsed first to then initialise the required structures to parse the other predictions. 

This command only tests collisions between the **rig boxes** and the **environment boxes** for the detected grasp pose. 

**Hover, approach and exit poses are not tested.** 

**The robot body is not tested.** 

## **Command String** 

```
GET ALL PREDICTIONS NO TEST
```

## **Input Data** 

part name → string 

or 

part name → string grasp priority → csv integers 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

16/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

or 

part name → string 

grasp priority → csv integers ignored grasps → csv integers 

or 

part name → string 

- grasp priority → csv integers ignored grasps → csv integers sorting type→ integer 

## **Input Data Format** 

part_name 

or 

part_name*grasp_priority 

or 

part_name*grasp_priority*ignored_grasps 

or 

part_name*grasp_priority*ignored_grasps*sorting_type 

## **Output Data** 

list of values 

first value is the number of predictions, subsequent sets of 8 values represent individual predictions 

n_predictions,x,y,z,a,b,g,type,score,x,y,z,a,b,g,type,score,x,y… 

Similar to GET ALL PREDICTIONS but it doesn’t run any collision tests. 

## **Command String** 

```
GET LEFT POSE
```

## **Input Data** 

none 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

17/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Output Data** 

x,y,z,a,b,g 

Returns the pose of the left camera relative to the robot flange. 

## **Command String** 

```
GET NEXT PREDICTION
```

## **Input Data** 

none 

## **Output Data** 

on valid prediction: 

1,x,y,z,a,b,g,type,score no prediction: 0,0,0,0,0,0,0,0,0 

Gets the next prediction. 

After a `GET PREDICTION` command is run, this command can be used to get additional part predictions that might’ve been detected, one at a time. 

This command is only valid after executing a `GET PREDICTION` command. 

## **Command String** 

```
GET PREDICTION
```

## **Input Data** 

part name → string 

or 

part name → string 

grasp priority → csv integers 

or 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

18/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

part name → string 

grasp priority → csv integers 

- ignored grasps → csv integers 

or 

part name → string 

- grasp priority → csv integers 

- ignored grasps → csv integers sorting type→ integer 

## **Input Data Format** 

part_name 

or 

part_name*grasp_priority 

or 

part_name*grasp_priority*ignored_grasps 

or 

part_name*grasp_priority*ignored_grasps*sorting_type 

## **Output Data** 

on valid prediction: 1,x,y,z,a,b,g,type,score 

no prediction: 0,0,0,0,0,0,0,0,0 

Captures images and runs the requested AI model. 

The AI model is automatically loaded if needed. 

Sorting type can be: 

- 0 → Confidence (default) 

- 1 → Depth Ascending 

- 2 → Depth Descending 

- 3 → Visibility 

- 4 → Min Rotation 

- 5 → Top To Bottom 

- 6 → Bottom To Top 

7 → Left To Right 

8 → Right To Left 

- 9 → Top Left To Bottom Right 

- 10 → Top Right To Bottom Left 

- 11 → Bottom Left To Top Right 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

19/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

12 → Bottom Right To Top Left 

Returns the highest ranked prediction, according to the defined sorting type, that does not cause a collision with the rig boxes. 

If a priority was defined, the predictions are first ranked by grasp type and then by the defined sorting method, the highest ranking one is then returned. 

Grasp types included in the ignored grasps list are removed. 

The first value of the returned list should be evaluated first. Subsequent values should only be parsed if the first is 1. 

The XYZABG pose returned is always relative to the robot flange. 

This means that to get the pose in the robot world, the robot flange pose must be transposed by the received prediction pose. 

If a sorting type is defined it overrides the value selected in CambrianVision AI Model screen. 

This command only tests collisions between the **rig boxes** and the **environment boxes** for the detected grasp pose. 

**Hover, approach and exit poses are not tested.** 

**The robot body is not tested.** 

## **Command String** 

```
GET PREDICTION NO TEST
```

## **Input Data** 

part name → string 

or 

- part name → string 

- grasp priority → csv integers 

or 

- part name → string 

- grasp priority → csv integers ignored grasps → csv integers 

or 

- part name → string 

- grasp priority → csv integers ignored grasps → csv integers 

- sorting type→ integer 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

20/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Input Data Format** 

part_name 

or 

part_name*grasp_priority 

or 

part_name*grasp_priority*ignored_grasps 

or 

part_name*grasp_priority*ignored_grasps*sorting_type 

## **Output Data** 

on valid prediction: 

1,x,y,z,a,b,g,type,score no prediction: 0,0,0,0,0,0,0,0,0 

Similar to `GET PREDICTION` but skips all collision tests. 

## **Command String** 

```
GET RIG POSE
```

## **Input Data** 

none 

## **Output Data** 

x,y,z,a,b,g 

Returns the pose of the camera rig relative to the robot flange. 

Getting the rig pose can be useful when defining poses that point the camera rig at some desired target! 

## **Command String** 

```
GET SEARCH Z
```

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

21/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

## **Input Data** 

none 

## **Output Data** 

if last prediction was valid 

1,x,y,z,a,b,g 

no prediction 

0,0,0,0,0,0,0,0 

Returns the pose, in the frame of the robot base, that the current robot tool needs to move to so that the camera rig is aligned with the highest object in the last prediction taken. 

The first value of the returned list should be evaluated first. Subsequent values should only be parsed if the first is 1. 

## **Command String** 

```
LOAD MODEL
```

## **Input Data** 

part name → string 

## **Input Data Format** 

part_name 

## **Output Data** 

none 

Asynchronously loads an AI model. 

This function is meant to be used to load models ahead of them being needed, to hide their loading time. 

The part name provided must correspond to a valid AI model installed in the Cambrian PC. 

Installed AI models are located in ~/Desktop/Caint/Networks/ 

Ideally, a robot program should use this to load the necessary AI models at the start. 

This will prevent any additional waiting times when getting predictions for models that might not be loaded otherwise. 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

22/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Command String** 

```
LOG TEXT
```

## **Input Data** 

text → string 

## **Input Data Format** 

text 

## **Output Data** 

none 

Logs the provided text to the robot communication log. 

Useful for debugging purposes. 

## **Command String** 

## `PING` 

## **Input Data** 

none 

## **Output Data** 

none 

Pings the Cambrian PC. 

Can be used to test the connection to Cambrian VISION. 

Having a robot program that just tries to initiate the connection and send a ping is a sometimes powerful debugging tool. 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

23/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Command String** 

```
REPORT PICK RESULT
```

## **Input Data** 

- (optional) prediction_id → int 

pick_result → int (0 / 1) 

## **Input Data Format** 

prediction_id*pick_result 

or 

pick_result 

## **Output Data** 

none 

After getting predictions and attempting to pick, this command can be used to log the result of that pick. 

- pick_result = 1 for successful attempts 

- pick_result = 0 for failed attempts 

This information gets logged along the data relative to the previous prediction in its respective file located in ~/Desktop/Caint/PredictionLog. 

This data can later be collected and analysed to help identify multiple issues. 

## **Command String** 

```
SET EDGE TRIM
```

## **Input Data** 

model_name → string 

edge_trim → float 

## **Input Data Format** 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

24/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

model_name*edge_trim 

## **Output Data** 

none 

## **Requirements** 

Cambrian VISION v1.14.3b1 or later 

Override the provided model’s edge trim value. 

Predictions that fall outside the defined trim are discarded, see the example below where only predictions in the green area ill be considered valid. 

The value corresponds to the amount of padding applied, from all sides, to generate the valid region. Meaning a value of 0.1 ignores 10% of the image from the top, bottom, left and right. 

The value provided is clamped to a 0-0.4 range. 

The model must be loaded prior to calling this command. 

The value is not saved between models or restarts. 

**==> picture [375 x 120] intentionally omitted <==**

## **Command String** 

```
SMART SEARCH RANDOM
```

## **Input Data** 

none 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

25/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

## **Output Data** 

on valid reply: 

1,x,y,z,a,b,g,0 

otherwise: 

0,0,0,0,0,0,0,0 

When there’s memory of previously seen parts, this command returns the tool pose that the robot should move to in order to line up with those parts. 

The first value of the returned list should be evaluated first. Subsequent values should only be parsed if the first is 1. 

10% of the time this will return 0 even when there’s memory of other predictions. This is meant to prevent certain search algorithms from becoming stuck. 

## **Command String** 

```
START SESSION
```

## **Input Data** 

none 

## **Output Data** 

none 

Instructs Cambrian VISION to start a new session. 

This resets several system variables and reloads the camera rig parameters. 

Additionally, it starts a new log file. 

## **Command String** 

```
TOO CLOSE
```

## **Input Data** 

none 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

26/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Output Data** 

predictions too close → 1 

no predictions too close → 0 

Returns 1 if the latest prediction related command found parts too close from the working range of the model or 0 otherwise. 

This command can be useful to implement different search algorithms. 

When parts are seen too far from model’s working range the search position should be moved closer to the parts. 

## **Command String** 

```
TOO FAR
```

## **Input Data** 

none 

## **Output Data** 

predictions too far → 1 

no predictions too far → 0 

Returns 1 if the latest prediction related command found parts too far to the camera rig or 0 otherwise. 

This command can be useful to implement different search algorithms. 

When parts are too close to the cameras and outside the model’s working range the search position should be moved further away from the parts. 

## **Command String** 

```
UNLOAD ALL MODELS
```

## **Input Data** 

none 

## **Output Data** 

none 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

27/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

Unloads all AI models. 

Useful at the start of a robot program to make sure the GPU memory is fully cleared. 

After unloading models, it’s recommended to wait around 1 second before loading new ones, to make sure the memory has been freed. 

Some of our robot interfaces call this command automatically on program start. 

## **Command String** `UNLOAD MODEL` 

**Input Data** part name → string **Input Data Format** part_name **Output Data** none Unloads the specified AI model. 

After unloading models, it’s recommended to wait around 1 second before loading new ones, to make sure the memory has been freed. 

## **Command String** 

```
CHECK MODEL READY
```

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

28/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Input Data** 

part name → string 

## **Input Data Format** 

part_name 

## **Output Data** 

Model ready to use → 1 Model is not ready → 0 

Check if a model is loaded and ready. 

## **Command String** 

```
WAIT FOR MODEL LAUNCH
```

## **Input Data** 

part name → string 

## **Input Data Format** 

part_name 

## **Output Data** 

none 

If the model has loaded this command will wait until the model is ready. 

## **Command String** 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

29/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

```
LOAD MODEL FROM PATH
```

## **Input Data** 

full path → string 

## **Input Data Format** 

part_name 

## **Output Data** 

none 

Load a model from a full path. 

## **Command String** 

```
START PREDICTION AVERAGE
```

## **Input Data** 

threshold → float (millimeters) 

space → BASE / FLANGE 

## **Input Data Format** 

threshold 

or 

threshold*space 

## **Output Data** 

none 

Starts collecting predictions results and outputs an average when `END PREDICTION AVERAGE` is called. 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

30/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

Calling this command resets any previously collected data. 

After calling `START PREDICTION AVERAGE` , the first valid prediction of a prediction request will be stored as reference. In subsequent prediction requests, the closest valid prediction with the same grasp ID as the reference will be stored. 

If the distance the closest prediction and the reference is larger than the threshold, it will not be stored and a `WARNING` will be issued. 

The space specified in the command controls which space the predictions are stored. 

For `BASE` space, the predictions are converted into Robot Base space for averaging. It is suitable for parts that are stationary relative to the robot base. 

For `FLANGE` space, the predictions are converted into flange space for averaging. It is suitable for parts that are stationary relative to the robot flange. 

Calls END PREDICTION AVERAGE to get the average of the collected results in the space selected by `SET PREDICTION SPACE` 

The maximum predictions to store for averaging is 10. 

The default of threshold is 10mm if it’s not supplied. 

## **Command String** 

```
END PREDICTION AVERAGE
```

## **Input Data** 

none 

## **Output Data** 

with valid predictions: 

1,x,y,z,a,b,g 

no prediction: 

0,0,0,0,0,0,0 

Ends the prediction averaging session and outputs the average of the collected results in the selected space. 

## **Command String** 

```
SET MODEL CONFIDENCE
```

## **Input Data** 

model_name → string 

confidence → float 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

31/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

## **Input Data Format** 

model_name*confidence 

## **Output Data** 

none 

Sets the minimum confidence (0.0-1.0) filter of the model. 

Returns ERROR if the model is not loaded. 

## **Command String** 

```
SET MODEL RECENTER CROP
```

## **Input Data** 

model_name → string recenter_crop → float 

## **Input Data Format** 

model_name*recenter_crop 

## **Output Data** 

none 

Enable or disable recenter crop of the model. Set recenter_crop to 1 to enable and 0 to disable. 

Returns ERROR if the model is not loaded. 

## **Command String** 

```
GET GRASP COUNT
```

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

32/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

## **Input Data** 

none 

## **Output Data** 

grasp count → int 

Return the number or grasp points detected in the last prediction. 

## **Command String** 

```
GET PART COUNT
```

## **Input Data** 

none 

## **Output Data** 

part count → int 

Return the number or parts detected in the last prediction. 

For Full Pose models only. 

## **Command String** 

## `BLOCK VOLUME` 

## **Input Data** 

pose → csv pose values radius → float (meters) iterations → int 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

33/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Input Data Format** 

pose*radius*iterations 

## **Output Data** 

none 

Create a spherical volume at the specified pose in Robot Base space, which blocks any grasp point predictions within the volume from returning for the specified iterations of prediction requests. 

Multiple volumes can be created. If the centre of a volume is within the FOV and a prediction request is made, the iterations count is decremented. When the count reaches zero the volume is removed. 

Blocked volume show up as a semi-transparent red sphere in CambrianVISION 

## **Command String** 

```
CLEAR BLOCK VOLUMES
```

## **Input Data** 

none 

## **Output Data** 

none 

Clear all block volumes. 

Search Grid Commands 

## **Command String** 

```
SEARCH GRID BLOCK
```

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

34/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Input Data** 

- (optional) grid_name → string 

- cell x → int 

cell y → int 

block_iterations → int 

## **Input Data Format** 

cell_x*cell_y*block_iterations 

## or 

grid_name*cell_x*cell_y*block_iterations 

## **Output Data** 

none 

This command is only valid if a search grid has been configured. 

Block the search grid cell identified by column X and row Y by a the given number of search cycles. 

`SEARCH GRID GET NEXT` will not suggest the blocked cell for as many iterations as defined by the `block_iterations` argument. 

For example, blocking the cell for 5 iterations means that in the next 5 calls to `SEARCH GRID GET NEXT` , the cell won’t be returned. If multiple search grids have been configured, the name of the grid must be specified. 

Blocked cells show up as red in the Cambrian VISION UI 

If all grid cells become blocked, they all get automatically unblocked. 

## **Command String** 

```
SEARCH GRID CHECK INIT
```

## **Input Data** 

grid_name → string 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

35/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Input Data Format** 

grid_name 

## **Output Data** 

already exits → 1 

does not exist → 0 

Checks if the search grid with the provided name already exists. Returns 1 if it exists or 0 otherwise. 

## **Command String** 

```
SEARCH GRID DESTROY
```

## **Input Data** 

grid_name → string 

## **Input Data Format** 

grid_name 

## **Output Data** 

none Destroys the specified search grid. 

## **Command String** 

```
SEARCH GRID DESTROY ALL
```

## **Input Data** 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

36/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

none 

## **Output Data** 

none 

Destroys all grids. 

This is useful when switching between programs that use differently named search grids. 

## **Command String** 

## `SEARCH GRID FINISHED` 

## **Input Data** 

(optional) grid_name → string 

## **Input Data Format** 

none 

or 

grid_name 

## **Output Data** 

grid finished → 1 

grid not finished → 0 

This command is only valid if a search grid has been configured. 

When the grid has been fully explored (meaning all cells have advanced to their maximum allowed depth) this command returns 1. Returns 0 otherwise. 

If multiple search grids have been configured, the name of the grid must be specified. 

When a grid is finished, all its cells show up as yellow in the Cambrian VISION UI 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

37/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

## **Command String** 

```
SEARCH GRID GET NEXT
```

## **Input Data** 

- (optional) grid_name → string 

## **Input Data Format** 

none 

or 

grid_name 

## **Output Data** 

x,y,z,a,b,g,cell_x,cell_y 

This command is only valid if a search grid has been configured. 

Returns the next cell that the robot should move to. 

The pose is defined in tool coordinates meaning the robot should move the current tool to the returned pose. 

Additionally the cell's X and Y coordinates are returned. This can be used to block the returned cell with `SEARCH GRID BLOCK` . 

If multiple search grids have been configured, the name of the grid must be specified. 

## **Command String** 

```
SEARCH GRID GET CELL
```

## **Input Data** 

- (optional) grid_name → string 

cell_x → int 

cell_y → int 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

38/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Input Data Format** 

cell_x*cell_y 

or 

grid_name*cell_x*cell_y 

## **Output Data** 

pose → csv floats 

cell_x → int 

cell_y → int 

Retrieves the pose of a specific cell in the search grid. Provide the x and y indices of the desired cell. The pose of the cell is returned relative to the robot BASE. 

The x and y indices are also returned so that the return format matches that of `SEARCH GRID GET NEXT` . 

Cambrian VISION 2.3 or later 

## **Command String** 

```
SEARCH GRID IGNORE
```

## **Input Data** 

- (optional) grid_name → string 

cell_x → int 

cell_y → int 

## **Input Data Format** 

grid_name*cell_x*cell_y 

or 

cell_x*cell_y 

## **Output Data** 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

39/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

none 

This command is only valid if a search grid has been configured. 

Ignore the given search grid cell. 

Ignored cells are not taken into account by `SEARCH GRID FINISHED` command. 

Ignored cells are never returned by `SEARCH GRID GET NEXT` . 

This command can also be used to customise a search grid. 

For example, by removing its corners or all cells in a certain row. 

## **Command String** 

## `SEARCH GRID INIT` 

## **Input Data** 

- (optional) grid_name → string 

- grid pose → csv pose 

- x cells → int 

- y cells → int 

- max Z (in mm)→ float 

- cell size X (in mm)→ float 

- cell size Y (in mm)→ float 

- Z step (in mm)→ float 

## **Input Data Format** 

grid_pose*x_cells*y_cells*max_Z*cell_size_x*cell_size_y*z_step 

## or 

grid_name*grid_pose*x_cells*y_cells*max_Z*cell_size_x*cell_size_y*z_step 

## **Output Data** 

none 

Initialises a new search grid. 

The search grid helps exploring deeper boxes, it updates the height of its cells dynamically, as parts are picked. 

The grid pose should be the top left corner of the grid. 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

40/62 

Cambrian VISION API | Cambrian VISION Documentation 

## 5/15/26, 1:59 PM 

X cells and Y cells define the number of cells of the grid in horizontal and vertical axis. 

Max Z defines how much, in the grid pose’s Z axis, the robot is allowed to go forward, in mm. This value should be slightly smaller than the distance between the robot tool and the box floor, from the defined grid pose. 

Cell sizes X and Y determine the horizontal and vertical size of the cells, in mm. These values can be negative to invert the grid in its corresponding axis. 

Z step is the maximum depth increment the cell is allowed to do per cycle, in mm. This should be smaller than the range of the AI model being used. 

**==> picture [210 x 137] intentionally omitted <==**

**==> picture [266 x 138] intentionally omitted <==**

If multiple search grids have been configured, the name of the grid must be specified. 

If a grid with the given name already exists, it is reset. 

## **Command String** 

```
SEARCH GRID LEVEL
```

## **Input Data** 

- (optional) grid_name → string 

## **Input Data Format** 

grid_name 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

41/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

## **Output Data** 

grid_level 

## **Requirements** 

Cambrian VISION v1.14.3b1 or later 

Get the fill level of the specified search grid. 

This is meant to be used to, for example, issue a warning if a bin is close to being empty. 

The fill level is the normalised average value of the non ignored grid cells. 

When a grid is first initialised its level is 1. 

When a grid is fully explored its level is 0. 

The fill level can be larger than 1 if the search grid has, on average, moved back from its initial value. 

**==> picture [393 x 162] intentionally omitted <==**

## **Command String** 

**==> picture [73 x 10] intentionally omitted <==**

**----- Start of picture text -----**<br>
SEARCH GRID RESET<br>**----- End of picture text -----**<br>


## **Input Data** 

- (optional) grid_name → string 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

42/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Input Data Format** 

none 

or 

grid_name 

## **Output Data** 

## none 

This command is only valid if a search grid has been configured. 

Resets all cells of the search grid to their initial height (same state as right after it was created using `SEARCH GRID INIT` ). 

If multiple search grids have been configured, the name of the grid must be specified. 

## **Command String** 

```
SEARCH GRID REPORT
```

## **Input Data** 

- (optional) grid_name → string 

- cell_x → int 

- cell_y → int 

- result → int 

## **Input Data Format** 

grid_name*cell_x*cell_y*result 

or 

cell_x*cell_y*result 

## **Output Data** 

successive_bad_visits, total_bad_visits 

This command is only valid if a search grid has been configured. 

After attempting to pick a part, this command can be used to report to the Cambrian UI if the pick, from the given search grid cell, was successful or not. 

A successful pick should be reported as 1. Unsuccessful as 0. 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

43/62 

5/15/26, 1:59 PM 

## Cambrian VISION API | Cambrian VISION Documentation 

The command then returns the number of reported failed attempts from the given cell and the total number of reported failed attempts. 

This result is meant to be used along the `SEARCH GRID IGNORE` command to completely block a cell that is producing unsuccessful picks. 

## For example: 

- `1 # report a fail on cell with coordinates (3,4)` 

- `2 successive_fails, total_fails = cambrian_request("SEARCH GRID REPORT", "GRID*3*4*0")` 

- `3` 

- `4 # ignore this cell if it results in too many fails` 

- `5 if successive_fails > 5 or total_fails > 10` 

- `6 cambrian_request("SEARCH GRID IGNORE", "GRID*3*4")` 

## **Command String** 

```
SEARCH GRID UPDATE
```

## **Input Data** 

- (optional) grid_name → string 

## **Input Data Format** 

none 

or 

grid_name 

## **Output Data** 

## none 

This command is only valid if a search grid has been configured. 

Updates the last cell of the grid returned by `SEARCH GRID GET NEXT` with information from the last prediction request. 

It’s important that this command is called even if no valid predictions were found, otherwise the cell won’t ever move deeper into the box. 

When parts are detected to be too close to the cameras, the cell is moved back (Z negative). 

When parts are detected too far or not at all, the cell is moved forward (Z positive), deeper into the box. 

The cell is never moved forward more than the defined max Z and only (up to) Z step per update. 

If multiple search grids have been configured, the name of the grid must be specified. 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

44/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

This command really **must** be called after any `GET PREDICTION` whether predictions were received or not. 

## **Command String** 

```
SEARCH GRID GET CELL LEVEL
```

## **Input Data** 

- (optional) grid_name → string 

cell_x → int cell_y → int 

## **Input Data Format** 

cell_x*cell_y 

or 

grid_name*cell_x*cell_y 

## **Output Data** 

cell_level → float 

This command is only valid if a search grid has been configured. 

Get the level of a specified cell. 

The value can range from 0 to infinity. 

When a search grid is initialised, all cells have a level of 1. 

Cambrian VISION 2.3 or later 

## **Command String** 

```
SEARCH GRID SET CELL LEVEL
```

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

45/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Input Data** 

- (optional) grid_name → string 

cell_x → int 

cell_y → int 

cell_level → float 

## **Input Data Format** 

cell_x*cell_y*cell_level 

or 

grid_name*cell_x*cell_y*cell_level 

## **Output Data** 

none 

This command is only valid if a search grid has been configured. 

Set the level of a specified cell. 

Setting the level to 1 is equivalent to reset the cell to its initial state. 

It’s possible to configure cells to be higher than their initial value. 

The value can range from 0 to infinity. 

Cambrian VISION 2.0 or later 

## **Command String** 

```
SEARCH GRID SET LEVEL
```

## **Input Data** 

- (optional) grid_name → string 

cell_level → float 

## **Input Data Format** 

cell_level 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

46/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

or 

grid_name*cell_level 

## **Output Data** 

## none 

This command is only valid if a search grid has been configured. 

Set the level of all cells of a search grid. 

Setting the level to 1 is equivalent to reset the cells to their initial state. 

It’s possible to configure cells to be higher than their initial value. 

The value can range from 0 to infinity. 

Cambrian VISION 2.0 or later 

## **Command String** 

```
SEARCH GRID SET WEIGHTS
```

## **Input Data** 

- (optional) grid_name → string 

weights → csv floats 

## **Input Data Format** 

weights 

or 

grid_name*weights 

## **Output Data** 

## none 

The `SEARCH GRID NEXT` command described above calculates grid cell “scores” to determine which is the best cell to visit next. 

We use several different metrics to calculate the scores for each grid cell. The final cell scores are then calculated as a weighted sum of the per-metric scores for each cell. The weights that are used in the final sum dictate how important each metric is in the final calculation and can https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

47/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

be used to change the behaviour of the search algorithm to best suite the needs of the task. 

This command sets the weights of the specified search grid. 

The command expects 6 weight values in csv format. These values correspond to the following metrics: 

|**Metric**|**Description**|**Default**<br>**value**|
|---|---|---|
|`Cell Height`|Height of the search grid cell - dictated by the height of the parts in that<br>area of the box. Weight > 0 preferences taller cells, i.e. areas with the<br>highest parts in the box.|0.5|
|`Distance to Centre of Search Grid`|Distance of the cell from the centre of the search grid. Weight > 0<br>preferences central cells. Weight < 0 preferences outer cells.|0.05|
|`Distance to Last Visited Cell`|Distance of this cell to the most recently visited search grid cell.<br>Weight > 0 preferences cells closer to the previous search cell.|0.25|
|`Number of Predictions`|Number of predictions that were seen from this cell on the last<br>visit. Weight > 0 preferences cells with more predictions on the<br>previous visit.|0.1|
|`Iterations Since Last Visit`|Number of iterations since the robot last visited this search cell.<br>Weights > 0 preferences cells not visited in a while.|0.1|
|`Cell Selection Randomness Factor`|When<br>`SEARCH GRID GET NEXT`is called, the next search cell is picked at<br>random from the best**N**% of cells by score. This weight is the decimal<br>equivalent of**N**% (i.e.**N**/100).|0.1|



Cambrian VISION 2.0 or later 

## **Command String** 

```
SEARCH GRID GET WEIGHTS
```

## **Input Data** 

(optional) grid_name → string 

## **Input Data Format** 

none 

or 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

48/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

grid_name 

## **Output Data** 

weights → csv floats 

Returns the weights of the specified search grid. 

See `SEARCH GRID SET WEIGHTS` above for a description of the weights. 

Cambrian VISION 2.0 or later 

## **Command String** 

```
SEARCH GRID AUTO INIT
```

## **Input Data** 

grid_name → string 

box_name → string model_name → string 

- (optional) rotate_grid→ int ([0, 1, 2, or 3], default: 0) 

- (optional) fov_scaling_factor → float (> 0, default: 0.8) 

- (optional) fov_overlap_ratios → csv floats (length: 2, <=1, default: 0) 

## **Input Data Format** 

grid_name*box_name*model_name*(rotate_grid)*(fov_scaling_factor)*(fov_overlap_ratios) 

## **Output Data** 

num_x_cells → int num_y_cells → int 

Initialises a search grid automatically for a specified concave box or world-space collision component (CAD imported box). Returns the number of cells in x and y directions of the newly created search grid. 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

49/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

Provide the following required parameters: 

## `grid_name` : 

A name for the search grid (e.g., `"my_grid"` ). 

## `box_name` : 

The Box or CAD component to create the search grid above (e.g., `"Box_0"` or `"MyCadBox_1"` ). 

## `model_name` : 

The name of the AI Model you will be using (e.g., `"My_Model"` ). 

Optionally provide the following parameters: 

## `rotate_grid` : 

If you want to rotate the grid (and thus the camera orientation of the search cells) to a different orientation with respect to the box, then you can specify the number of 90 degree rotations from the default: `0` = 0 degrees offset (default), `1` = 90 degrees offset, `2` = 180 degree offset, `3` = 270 degree offset. 

## `fov_scaling_factor` : 

If you want the grid cells closer together or further apart, you can decrease or increase `fov_scaling_factor` respectively. A value of `1` means the whole FoV is considered in grid spacing calulcations. A value of less than `1` means that the cells will be closer together. A value of more than `1` means the cells will be further apart. The default is `0.8` which gives some overlap in camera images between neighbouring cells. 

**==> picture [410 x 182] intentionally omitted <==**

## `fov_overlap_ratios` : 

If you want to change the density of the grid asymmetrically, you can override the cell FoV overlap in either axis of the grid by explicitly setting `fov_overlap_ratios` . In this case, the decimal value you specify for each axis represents the exact overlap you want between the FoVs of neighbouring cells (see images below). Please specify values for both axes, separated by commas (e.g. `“0.2,0”` or `“-0.1,1”` ) 

- A value of `0` for either axis reverts to the default behaviour which is to scale the overlap ratio so that the span of the FoVs exactly fits the box width/depth. An overlap ratio of `1` means 100% overlap between neighbouring cells; in that case, the number of cells in that axis is reduced to 1 (regardless of box span). A negative overlap means that there will be gaps between the FoVs of neigbouring cells. E.g. an overlap ratio of `-0.1` means a 10% gap between cells in that axis. 

- A minimum spacing of `50mm` between cells is applied when the `fov_overlap_ratio` is default ( `0` ). If you specify a non-zero overlap ratio, then this minimum does not apply. 

It is recommended to use `fov_scaling_factor` to increase/decrease the density of the grid cells and only use `fov_overlap_ratios` if you require asymmetric grid density alterations. 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

50/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**==> picture [486 x 283] intentionally omitted <==**

Cambrian VISION 2.3 or later 

## **Command String** 

```
SEARCH GRID DIMENSIONS
```

## **Input Data** 

- (optional) grid_name → string 

## **Input Data Format** 

none 

or 

grid_name 

## **Output Data** 

num_x_cells → int num_y_cells → int 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

51/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

Returns the number of cells in the x and y directions of the search grid. 

E.g. the following search grid would return `“4,3”` 

**==> picture [210 x 138] intentionally omitted <==**

Cambrian VISION 2.3 or later 

## Workspace Components Commands 

## **Command String** 

## `3 POINT BOX` 

## **Input Data** 

box name → string 

- point1 → csv pose values point2 → csv pose values point3 → csv pose values depth (in meters)→ float wall thickness (in meters) → float 

## **Input Data Format** 

box_name*point1*point2*point3*depth*thickness 

## **Reply** 

none 

Creates a box from 3 upper corners of a box to be used for collision testing. 

The pose and XY dimensions of the box are calculated from these 3 points. 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

52/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

Depth and wall thickness (in meters) must also be provided. 

The provided points must be from continuous and in clockwise order (when looking at the box from above. 

If a box with a same name already exists, it is overwritten. 

**==> picture [258 x 148] intentionally omitted <==**

**==> picture [332 x 141] intentionally omitted <==**

## **Command String** 

- `4 POINT BOX` 

## **Input Data** 

box name → string point1 → csv pose values point2 → csv pose values point3 → csv pose values point4 → csv pose values wall thickness (in meters) → float 

## **Input Data Format** 

box_name*point1*point2*point3*point4*thickness 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

53/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

## **Reply** 

none 

Similar to the `3 POINT BOX` command above but instead of providing the depth of the box, a point located anywhere in the box’s floor is given. The box depth is inferred from the distance between the plane formed by P1, P2 and P3 and P4. 

**==> picture [208 x 119] intentionally omitted <==**

## **Command String** 

```
CLEAR COLLISION ELEMENTS
```

## **Input Data** 

none 

## **Output Data** 

none 

Delete all collision boxes (includes environment boxes and flange attached boxes). 

## **Command String** 

```
SET BOX
```

## **Input Data** 

box name → string 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

54/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

pose → csv pose 

XYZ size (in meters)→ csv floats 

thickness (in meters)→ float 

## **Input Data Format** 

box_name*csv_pose*x_size,y_size,z_size*thickness 

## **Output Data** 

none 

Creates an environment box. 

If a box with the same name exists, it is overwritten. 

When the thickness is 0, a solid box is created (like a cuboid). 

If a positive thickness value is provided, a concave box is created instead with the walls being of the given thickness. 

The XYZ sizes define the size of the box along the corresponding axes. 

When creating a solid box, the provided pose will define its center. 

When creating a concave box, the provided pose defines the center of the box’s “floor”. 

## **Command String** 

```
SET GRIPPER BOX
```

## **Input Data** 

box name → string 

pose → csv pose 

XYZ size (in meters)→ csv floats 

## **Input Data Format** 

box_name*csv_pose*x_size,y_size,z_size 

## **Output Data** 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

55/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

none 

Creates a flange attached box (aka gripper box). 

If a box with the same name exists, it is overwritten. 

The XYZ sizes define the size of the box along the corresponding axes. 

The provided pose corresponds to the center of the box relative to the robot flange. 

## **Command String** 

## `SPAWN COMPONENT WORLD` 

## **Input Data** 

cad_name 

name → string pose → csv pose 

## **Input Data Format** 

cad_name*name*csv_pose 

## **Output Data** 

## none 

Creates an environment component using an object in the component library. 

Argument “cad_name” is the name of the object in the component library. 

Argument “name” corresponds to the imported object that has been imported to the scene. Pose provided is with respect to the robot base coordinates. 

If a component with the same name exists, it is overwritten. 

Returns ERROR if cad_name does not exists in the library. 

Note: The required CAD file must be imported to the World Component Library before calling this command. 

## **Command String** 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

56/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

```
SPAWN COMPONENT FLANGE
```

## **Input Data** 

cad_name name → string pose → csv pose 

## **Input Data Format** 

cad_name*name*csv_pose 

## **Output Data** 

none 

Creates an flange component using an object in the component library. 

Argument “cad_name” is the name of the object in the component library. 

Argument “name” corresponds to the imported object that has been imported to the scene. 

Pose provided is with respect to the robot flange coordinates. 

If a component with the same name exists, it is overwritten. 

Returns ERROR if cad_name does not exists in the library. 

Note: The required CAD file must be imported to the Flange Component Library before calling this command. 

## **Command String** 

```
SET COMPONENT WORLD POSE
```

## **Input Data** 

box_name → string 

pose → csv pose 

## **Input Data Format** 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

57/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

box_name*csv_pose 

## **Output Data** 

## none 

Sets the pose of an environment component with box_name. 

Returns ERROR if the environment component does not exists. 

## **Command String** 

```
SET COMPONENT FLANGE POSE
```

## **Input Data** 

box_name → string 

pose → csv pose 

## **Input Data Format** 

box_name*csv_pose 

## **Output Data** 

## none 

Sets the pose of a flange component with box_name. 

Returns ERROR if the flange component does not exists. 

## **Command String** 

```
DESTROY COMPONENT WORLD
```

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

58/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Input Data** 

box_name → string 

## **Input Data Format** 

box_name 

## **Output Data** 

none 

Destroy the environment component with box_name. 

## **Command String** 

```
DESTROY COMPONENT FLANGE
```

## **Input Data** 

box_name → string 

## **Input Data Format** 

box_name 

## **Output Data** 

none 

Destroy the flange component with box_name. 

## Collision Testing Commands 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

59/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

**Command String** 

```
ABB TEST POSE
```

## **Alias of** TEST POSE 

Please use `TEST POSE` for new development. 

## **Command String** 

## `UR POSE TEST` 

## **Alias of** TEST POSE WITHBODY 

Please use `TEST POSE WITHBODY` for new development. 

## **Command String** 

## `DOOSAN POSE TEST` 

## **Alias of** TEST POSE WITHBODY 

Please use `TEST POSE WITHBODY` for new development. 

## **Command String** 

## `KUKA POSE TEST` 

## **Alias of** TEST POSE WITHBODY 

Please use `TEST POSE WITHBODY` for new development. 

## **Command String** 

## `CHECK BODY` 

## **Input Data** 

none 

## **Output Data** 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

60/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

valid body → 1 

no valid body → 0 

Returns true if the currently selected robot is valid for collision detection with the robot body. 

Only valid the robot selected in Cambrian VISION is the correct model! Not valid when selecting generic interfaces. 

## **Command String** 

## `TEST POSE` 

## **Input Data** pose → csv pose 

## **Input Data Format** 

pose 

## **Output Data** 

colliding → 0,0,0,0,0,0,0,0,0 not colliding → 1,0,0,0,0,0,0,0,0 

Test the rig collision boxes against environment boxes. 

Returns 1 if the pose is safe or 0 otherwise. 

This command only tests collisions between the **rig boxes** and the **environment boxes** for the detected grasp pose. 

**The robot body is not tested.** 

## **Command String** 

```
TEST POSE WITHBODY
```

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

61/62 

Cambrian VISION API | Cambrian VISION Documentation 

5/15/26, 1:59 PM 

## **Input Data** 

ur joints → csv joints 

## **Input Data Format** 

csv_joints 

## **Output Data** 

collision → 1 no collision → 0 

Tests a given robot pose for collisions against the environment. This tests both the flange attached boxes as well as the robot body. The input should be a comma separated list of the 6 value joint configuration to be tested. 

Only valid if the robot selected in Cambrian VISION is the correct model! Not valid when selecting generic interfaces. 

Previous page Cambrian VISION User Interface 

cambrianrobotics.ai 

Copyright © 2026 Cambrian Robotics Ltd.・ Powered by Scroll Sites & Atlassian Confluence 

https://documentation.cambrianrobotics.ai/en/cambrian-vision-application/2.3/cambrian-vision-api 

62/62 

