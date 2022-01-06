;+
;-
pro write_barrys_dat_file, f10full

  values = uint( f10full.f10 * 10UL ) ; Barry encoded as tenths of an SFU
  ; value needs to have fill for missing data
  epochjd = julday(2,14,1947, 12,0,0) ; noon Feb 14, 1947

  ; first value should be the epochjd, but later values
  ; may be listed as later times
  tmp = min( abs(f10full.jd - epochjd), startidx )

  print,'INFO: writing newt7.dat'
  openw, lun, /get,'newt7.dat',/swap_if_big_endian
  writeu, lun, values[startidx:*] 
  free_lun, lun
  print,'INFO: wrote newt7.dat'
  return
end

;+
; This function calls LaTiS to download data as a string, then convert
; to floating point data types. Optionally retrieves the NOAA
; historical f10.7 record.
;-
function retrieve_f10, noaaf10=noaaf10
  
  ; LISIRD
  base_url = 'https://lasp.colorado.edu/lisird/latis/dap/'  

  localfilepath = getenv('see_solndx_data')
  if localfilepath eq '' then localfilepath = '~' ; use home
  localfilepath = localfilepath + '/'
  
  ; a temporary file to prevent multiple unnecessary downloads
  f10file = localfilepath+'penticton_radio_flux.sav'

  finfo = file_info(f10file)
  if finfo.exists eq 1 then begin
     if systime(1) - finfo.ctime lt 43200 then begin
        skip_restore=0
        goto, restore_the_savefile
     endif
  endif
  skip_restore = 1 ; download a fresh dataset
  
  dataset_url = base_url + 'penticton_radio_flux.csv?time,adjusted_flux&exclude_missing()' ; skip any fill values
  
  print,'INFO: retrieve_f10 downloading f10 from LISIRD LATIS'
  f10str = latis_geturlasstring( dataset_url ) ; jd, adjflux
  print,'INFO: retrieve_f10 data received.'
  
  ; f10str looks like this
  ; time (Julian Date),adjusted_flux (solar flux unit (SFU))
  ;2432231.2,254.0
  ;2432234.2,228.8
  ;2432236.2,179.0
  ;2432237.2,163.7
  
  ; need to strip off the first header row
  f10str = f10str[1:*]
  
  f10_rec = {jd:0.d, f10:0.}
  f10full=replicate(f10_rec, n_elements(f10str))
  ptmp = (strsplit(f10str,',',/extract)).toarray() ; convert list to 2d array
  f10full.jd = double(ptmp[*,0])
  f10full.f10 = float(ptmp[*,1])

  save,file=f10file,f10full,/compress
  skip_restore=1

  restore_the_savefile:
  if skip_restore ne 1 then begin
     print,'restoring '+f10file+' instead of downloading from LATIS'
     restore, f10file           ; f10full
  endif
  
  ; this has multiple measurements per day

  ; try to manually repair some errors in the F10.7 record
  ; these are where time jumps backwards
  f10full[25297:25299].jd += 1  ; off by one day
  f10full[25349:25350].jd += 1 ; off by one day
  f10full[25493:25495].jd += 1 ; off by one day
  f10full[25573:25575].jd += 1 ; off by one day
  f10full[26416:26418].jd += 1 ; off by one day
  f10full[32923].jd -= 1 ; off by one day
  f10full[34516].jd += 1 ; off by one day
  f10full[34514:34516].jd += 1 ; off by one day
  f10full[43067].jd += 1 ; this value is bad (f10=1661.8) and the date is wrong

  ; not all time jumps are fixed. Some days have extra data.
  
  ; must sort data into time order
  idx = sort(f10full.jd)
  f10full = f10full[idx] ; reassign in sorted order
  
  if size(noaaf10,/type) eq 0 then return, f10full
  
  ; retrieve the NOAA adjusted solar radio flux dataset that stopped 
  ; NOAA dataset ranges from 1947045-2018119
  
  dataset_url = base_url + 'noaa_radio_flux.csv?&exclude_missing()' ; all times

  noaafile = localfilepath+'noaa_radio_flux.sav'
  
  finfo = file_info(noaafile)
  if finfo.exists eq 1 then begin
     print,'restoring noaafile '+noaafile
     restore,noaafile           ; this is a static dataset now
  endif 

  if size(noaaf10,/type) ne 8 then begin
  
     print,'INFO: retrieve_f10 downloading NOAA f10 from LISIRD LATIS'
     noaa  = latis_geturlasstring( dataset_url )
     print,'INFO: retrieve_f10 data received.'

     ; noaa looks like this (no fractional day)
     ;time (yyyyMMdd),f107 (solar flux unit (SFU))
     ;19470214,253.9
     ;19470217,228.5
     ;19470219,178.8

     noaa = noaa[1:*]           ; strip off header line
     noaa_rec = {yyyymmdd:0L, jd:0.d, f10:0.}
     noaaf10 = replicate(noaa_rec, n_elements(noaa))
     mtmp = (strsplit(noaa,',',/extract)).toarray() ; convert list to array
     noaaf10.yyyymmdd = long(mtmp[*,0])
     noaaf10.f10 = float(mtmp[*,1])

     yyyy = noaaf10.yyyymmdd / 10000L
     mm = (noaaf10.yyyymmdd / 100L) mod 100L
     dd = noaaf10.yyyymmdd mod 100L
     noaaf10.jd = julday( mm, dd, yyyy, 12 ) ; use IDL built-in at noon UTC
     
     save,file=noaafile, noaaf10,/compress
  endif
  
  ; compare the noaa and f10 datasets for a common day that has a burst
  ; a burst occured on jd=2451044.5
  ; no other measurements occurred on that date

  ; another burst occurred on jd=2451680.2
  ; 3 values occurred that day 890.9, 249.9, 244.6 at .2, .3, and .5
  ; fraction of jd respectively
  ; the NOAA value reported for 20000515 or 2451680.0 is 249.9, so it selected
  ; the middle one
  ; TAKE-AWAY : USE THE MIDDLE VALUE IF IT IS GOOD

  ; another burst happened at jd=2452005.2
  ; 3 value reported, 583.2, 399.2, 207.8
  ; noaa reported 207.8
  ; TAKE-AWAY: Use any available if all the rest are bursts
  
  ; another burst happened at jd=2452006.3
  ; 3 values reported 192.0, 564.5, 198.0
  ; noaa reported 192.0
  ; TAKE-AWAY: Use first value if middle is a burst
  

  ; preliminary algorithm
  ; Use middle value, if it exceeds some thredhold it is a burst
  ; If the first value is good use that
  ; if the first value is also a burst, use the 3rd value

  ; If all are bursts? all bets are off, try interpolation across 
  ; previous and next days maybe?
  
  ;stop
  return, f10full
end

;+
; This function is for users of MSIS or other software that expects on
; F10.7 cm radio flux measurement for each day. It returns an array of
; structures containing the 10.7 cm radio flux, the 81-day running
; mean, a JD, and a YYYYMMDD. This code calculates the JD using IDL
; built-in functions. The JD converted value uses the conversion
; corresponding to noon UTC for the YYYYMMDD in the historical record.
;
; This returns the NGDC/NOAA historical record where it exists
; (1947-2018). After it stopped updating, this code uses penticton
; data and creates a daily value from one of the available
; measurements in the day. The NGDC data provides one value for each
; day. The historical convention is to provide the date as
; YYYYMMDD. No fractional day information is provided, so the newer
; data follows that convention. An attempt to remove radio bursts is
; made.  Ken Tapping claims F10 is only good to 1% or 1 SFU whichever
; is larger.
; 
; The penticton record is long but it unfortunately contains numerous
; typos and dates that are missing/duplicated caused by human error in
; transcribing the values. Some dates appear to be copied/pasted from
; the previous entries and were not changed.  Obvious duplicate dates
; are corrected, but some are not. There are no clear data gaps around
; some dates that have duplicated times.
;
; :Params:
;   None
;
; :Keywords:
;   showplot: in, optional, type=boolean
;     Set to generate a plot.
;   write_barrys_file: in, optional, type=boolean
;     Set to create the newt7.dat file for use by MSIS routines.
;
; :Returns:
;   This function returns an array of structures that looks as
;   follows.
;   IDL> help,s,/str
;   ** Structure <1656448>, 5 tags, length=24, data length=18, refs=1:
;      JD              DOUBLE           2432231.0
;      F10             FLOAT           253.900
;      F10A            FLOAT           227.004
;      BURST           BYTE         0
;      NMEAS           BYTE         1
;   JD is the julian date equivalent at noon UTC for the day.
;   It is a day counter since Jan 1, 4713 BC that increments at noon UTC.
;   F10 is the daily value of the 10.7 cm radio flux in SFU.
;   F10A is the 81-day average centered on the date.
;   BURST is a counter for radio bursts that were encountered, not all 
;   radio bursts are counted. When a good value is found it stops looking.
;   NMEAS is the number of measurements on that day.
;
;-
function download_f10, showplot=showplot, write_barrys_file=write_barrys_file

  common download_f10_cal, newdaily

  if size(newdaily,/type) ne 0 then return, newdaily
  
  noaa=1b ;  set it to anything, it is overwritten if provided to the function
  
  f10 = retrieve_f10(noaa=noaa)

  ; need to filter and apply the NOAA algorithm
  daily = apply_noaa_f10_algorithm( f10 )

  ; compare noaa to daily
  ; we use historical noaa values when it is available
  common_idx, long(noaa.jd), long(daily.jd), ni, di

  ; it looks like the NOAA data and the Penticton data involve a lot
  ; of human data entry because they disagree
  ; There are many instances where the dates are wrong in the
  ; penticton data. This could have messed up the NOAA data, too.
  ; The penticton data sometimes has too many measurments for a day.
  
  ;plot,noaa[ni].f10 - daily[di].f10,ys=1,xs=1

  ; Ken Tappings paper says 1DN or 1% uncertainty is expected
  ;bad = where( abs(noaa[ni].f10 - daily[di].f10) gt 0.9, n_bad )
  ; this is just the 41 biggest differences
  ;bad = where( abs(noaa[ni].f10 - daily[di].f10) gt 5, n_bad )
                                ;
  ; NOTE: the noaa[ni] and daily[di] values should be interrogated to 
  ; investigate the algorithm


  ; is the NOAA data "correct"
  ; use all of the noaa data if we believe it like this
   daily[di].f10 = noaa[ni].f10    ; use noaa values where penticton overlaps

  ; write the data to the binary file format Barry uses in get_t7
   if keyword_set(write_barrys_file) then $
      write_barrys_dat_file, daily

  ; calculate the moving average f10a
  newdaily = calc_f10_moving_avg( daily )

  if keyword_set(showplot) then begin
     tmp = label_date(date_format=['%Y'])
     plot, daily.jd, daily.f10, xtickformat='label_date',ytit='SFU',tit='F10.7 and <F10.7>81day'
     oplot, daily.jd,daily.f10a, co='fe'x
     stop
     tmp = label_date(date_format=['%D %M!C%Y'])
     plot, daily.jd, daily.f10, xtickformat='label_date', $
           xr=[-90,0]+daily[-1].jd, ps=-4, ys=1,ytit='SFU',tit='F10.7 and <F10.7>81day'
     oplot, daily.jd, daily.f10a, co='fe'x
     
  endif
  
  return, newdaily
end
