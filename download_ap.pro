;+
;-
function retrieve_little_ap
  
  ; space weather data portal
  base_url = 'https://lasp.colorado.edu/space-weather-portal/latis/dap/'
  
  dataset_url = base_url + 'ap.csv?time,ap&exclude_missing()' ; all times

  localfilepath = getenv('see_solndx_data')
  if localfilepath eq '' then localfilepath = '~' ; use home
  localfilepath = localfilepath + '/'

  apfile = localfilepath + 'ap_from_spwx_data_portal.sav'

  finfo = file_info(apfile)
  if finfo.exists eq 1 then begin
     if systime(1) - finfo.ctime lt 43200 then begin ; half a day old?
        skip_restore=0
        goto, restore_the_savefile
     endif
  endif
  skip_restore = 1 ; download a fresh dataset
  
  print,'INFO: retrieve_little_ap - requesting data'
  datastr = latis_geturlasstring( dataset_url )
  print,'INFO: retrieve_little_ap - data received'

  ;format of datastr is
  ;  time (yyMMdd HH),ap (nT)
  ;320101 00,18
  ;320101 03,12
  ;320101 06,9

  justdatastr = datastr[1:*]    ; strip off header line
  
  little_rec = {yyyymmdd:0L, hh:0, a:0L}
  little_ap = replicate(little_rec,n_elements(justdatastr))

  yymmdd = long(strmid(justdatastr,0,6)) ; convert to yyyymmdd
  yyyymmdd = yymmdd ; initialize
  y2k_idx = where(yymmdd lt 320101, comp=prey2k_idx)
  yyyymmdd[y2k_idx]    += 20000000L ; + yymmdd[y2k_idx]
  yyyymmdd[prey2k_idx] += 19000000L ;+ yymmdd[prey2k_idx]
  
  little_ap.yyyymmdd = yyyymmdd
  little_ap.hh = long(strmid(justdatastr,7,2))
  little_ap.a = long(strmid(justdatastr,10,2))

  save,file=apfile,little_ap,/compress
  skip_restore=1

  restore_the_savefile:
  if skip_restore ne 1 then begin
     print,'restoring '+apfile+' instead of downloading from LATIS'
     restore, apfile ; little_ap
  endif

  return, little_ap
end

;+
; Average the 3 hour values to a daily value.
; THe array is large, so search over the whole array is slow. This
; uses a trick to only search a small window of elements to find the
; values to average. If the input is not sorted then this approach
; will not work.
;
; :Params;
;    little_ap: in, required, type=array of structures
;      This is returned from retrieve_little_ap
;
;-
function convert_little_ap_to_dailyap, little_ap

  ;print,'INFO: convert_little_ap_to_dailyap starting'
  
  ; assume little_ap is sorted by date (yyyymmdd)

  ; find the unique days to be used in calculating the average
  uniqdays = little_ap[ uniq( little_ap.yyyymmdd ) ].yyyymmdd
  apmean = fltarr(n_elements( uniqdays )) ; should be only unique days
  ;apstar = apmean ; defined in https://www.ngdc.noaa.gov/stp/GEOMAG/ApStardescription.pdf
  
  ; for faster where statements, reduce number of elements by
  ; tracking first and last elements found
  first = 0L
  maxidx = n_elements(little_ap) - 1L
  for i=0,n_elements(apmean)-1 do begin
     ; the search range is from first to last
     last = (first + 9) < maxidx ; can only have up to 8
     idx = where(uniqdays[i] eq little_ap[first:last].yyyymmdd)

     ; remap idx back to little_ap
     ; identify the indices into little_ap.a array
     foundidx = idx + first
     apmean[i] = mean(little_ap[foundidx].a, /nan)

     first = foundidx[-1] + 1L  ;set for next iteration
     ;if i mod 100 eq 0  then print,i,' of ',n_elements(apmean)-1
  endfor
  ;print,'INFO: convert_little_ap_to_dailyap finished'

  ; define output
  ap_rec = {yyyymmdd:0L, jd:0.d, ap:0., apstar:0.}
  apdaily = replicate(ap_rec, n_elements(apmean))

  ; assign results
  apdaily.yyyymmdd = uniqdays
  apdaily.ap = apmean
  
  ; convert yyyymmdd to jd for convenience
  yyyy = uniqdays/10000L
  mm = (uniqdays / 100L) mod 100L
  dd = uniqdays mod 100L
  apdaily.jd = julday( mm, dd, yyyy, 12 ) ; noon UTC
  
  return, apdaily
end


;+
; This downloads data from the space weather data portal LATIS API.
; Little a is the 3 hour value, capital Ap is the daily average.
;-
function download_ap, little_a=little_a
  
  
  little_a_data = retrieve_little_ap()

  ap = convert_little_ap_to_dailyap( little_a_data )

  return, ap
end
