from skimage.metrics import structural_similarity
import cv2
import numpy as np
import sys
import glob
import os
import multiprocessing as mp
from pathlib import Path
from itertools import groupby
import datetime
import json
import re
import traceback

ERROR_THRESHOLD = 100

# Mean Squared Error
def mse(imageA, imageB):
  try:
    err = np.sum((imageA.astype("float") - imageB.astype("float")) ** 2)
    err /= float(imageA.shape[0] * imageA.shape[1])
    return err
  except Exception:
    # If this triggers, likely the image we are comparing to our "golden" image
    # has different dimensions. Both images need to be the same shape.
    traceback.print_exc()
    return -1


def do_mse(grayA, imageB):
  grayB = cv2.cvtColor(cv2.imread(imageB), cv2.COLOR_BGR2GRAY)
  diffScore = mse(grayA, grayB)
  result = None
  if (diffScore > ERROR_THRESHOLD):
    result = {'mse_score': round(diffScore, 10), 'path': os.path.basename(imageB)}
    #print(result)
  return result


# Structural Similarity Index
def ssim(imageA, imageB):
  (score, diff) = structural_similarity(imageA, imageB, full=True)
  return score


def main():
  if len(sys.argv) == 1:
    print ("Usage: image-diff.py goldenImage pathToImages imageExtension")
    return

  goldenImage = cv2.imread(sys.argv[1])
  pathToImages = sys.argv[2]
  imageExtension = sys.argv[3]
  cameraId = sys.argv[4]
  date = sys.argv[5]
  rolling_records_path = sys.argv[6]
  #re_search = re.search("guest_uploader\/(\w+)\/050-original-images\/(\d{4}-\d{2}-\d{2})\/?$", pathToImages)
  #(cameraId, date) = re_search.groups()


  if os.path.isfile(rolling_records_path):
    with open(rolling_records_path, 'r') as f:
      rolling_records = json.load(f)
  else:
    rolling_records = {}

  if cameraId not in rolling_records:
    rolling_records[cameraId] = {date: {}}
  elif date not in rolling_records[cameraId]:
    rolling_records[cameraId][date] = {}

  dates_for_cam = rolling_records[cameraId]
  day_records_for_cam = rolling_records[cameraId][date]

  # Convert images to grayscale
  grayA = cv2.cvtColor(goldenImage, cv2.COLOR_BGR2GRAY)
  images = sorted(glob.glob(os.path.join(pathToImages, "*." + imageExtension)), reverse=True)

  pool = mp.Pool()
  bad = pool.starmap(do_mse, ((grayA, image) for image in images))
  bad = list(filter(lambda item: item is not None, bad))

  grouped_by_hour = {}
  for item in bad:
    grouped_by_hour.setdefault(str(datetime.datetime.fromtimestamp(int(Path(item['path']).stem)).hour).zfill(2), []).append(item)

  for hour, v in grouped_by_hour.items():
    if hour in day_records_for_cam.keys():
      day_records_for_cam[hour] += v
    else:
      day_records_for_cam[hour] = v
    day_records_for_cam[hour] = sorted(day_records_for_cam[hour], key=lambda d: d['path'], reverse=True)

  rolling_records[cameraId][date] = dict(sorted(day_records_for_cam.items(), reverse=True))
  rolling_records[cameraId] = dict(sorted(dates_for_cam.items(), reverse=True))

  with open(rolling_records_path, "w") as outfile:
    outfile.write(json.dumps(rolling_records))


if __name__ == "__main__":
    main()
