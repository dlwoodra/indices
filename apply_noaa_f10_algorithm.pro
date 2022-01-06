;+
; This is an inferred algorithm based on behavior observed betwee the
; penticton F10 adjusted values and the NOAA reported radio flux.
;
; A daily value for F10.7 is needed to drive msis.
;
; The algorithms tries to use the center measurement in a day.
; If there are only two measurement in a day it tries to use the 
; last one. If there are 3 it uses the middle one initially.
; If there is only one value it uses that.
; It then checks if the value is a burst.
; This is just a simple threshold exceedence.
; If the threshold is crossed, then the first value in the day
; is used. If that value also exceeds the threshold, then the
; minimum from the day is used. 
;
; Radio bursts are stil possible for any day.
;
;-
function apply_noaa_f10_algorithm, f10_in

  ; find the list of unique days
  jdint = long(f10_in.jd) ; discard fraction
  uniqdays = jdint[ uniq(jdint) ]

  rec = {jd:0.d, f10:0., f10a:0., burst:0b, nmeas:0b}
  
  ; this also needs to store an 81-day centered running mean for msis
  ; count number of bursts and number of measurements in the day

  jumpthreshold = 120 ; if today is more than this much above yesteday then burst in progress

  minvalue = 61.59 ; lowest F10 value from first solar min
  ;maxvalue = 458.9 ; highest F10 value from first solar max
  maxvalue = 290. ; highest daily F10 value from sc23, when multiple measurements are provided
  
  daily = replicate(rec, n_elements(uniqdays))
  daily.jd = double(uniqdays)

  lastidx = 0L
  for i=0L,n_elements(daily)-1 do begin
     
     ; find the indices into f10_in that are measurements on this day
     ; first part of dataset has only one measurement
     idx = where( jdint[lastidx:*] eq uniqdays[i], n_meas )
     ; when multple measurements found, filter out bad values
     if n_meas gt 1 then begin
        idx = where( jdint[lastidx:*] eq uniqdays[i] and $
                  f10_in[lastidx:*].f10 gt minvalue and $
                  f10_in[lastidx:*].f10 lt maxvalue, n_meas )
     endif
     
     if n_meas ne 0 then begin
        idx += lastidx
        lastidx = idx[-1]
     endif else begin
        stop ; no matches this is an error
     endelse
     
     daily[i].nmeas = n_meas

     if n_meas eq 1 then begin
        ; most common case before for many decades
        daily[i].f10 = f10_in[idx[0]].f10
        ; flag it if it is a burst
        if i ne 0 and (daily[i].f10 - daily[i-1].f10 gt jumpthreshold) then daily[i].burst=1
        continue ; go to the next iteration
     endif

     if n_meas eq 2 then begin
        candidates = f10_in[idx].f10
        value = candidates[1] ; last is default

        if (value lt minvalue) or (value - daily[i-1].f10 gt jumpthreshold) then begin
           daily[i].burst += 1
           if candidates[0] - daily[i-1].f10 lt jumpthreshold then begin
              value=candidates[0] ; just first one
           endif
        endif

        ; are there multiple bursts?
        if value - daily[i-1].f10 gt jumpthreshold then begin
           daily[i].burst += 1
           value = min(candidates)
        endif
        daily[i].f10 = value
        continue
     endif

     if n_meas ge 3 then begin
        candidates = f10_in[idx].f10
        value = candidates[1] ; index=1 is default (not first, not last)

        if (value lt minvalue) or (value - daily[i-1].f10 gt jumpthreshold) then begin
           daily[i].burst += 1
           if candidates[0] - daily[i-1].f10 lt jumpthreshold then begin
              value=candidates[0] ; just first one
           endif
        endif

        ; are there multiple bursts?
        if (value - daily[i-1].f10 gt jumpthreshold) then begin
           daily[i].burst += 1
           if candidates[0] gt minvalue then value = candidates[0] else begin
              value = candidates[2] ; last resort
           endelse

        endif
        daily[i].f10 = value
        continue
     endif
     if n_meas gt 3 then begin
        print,'ERROR: apply_noaa_f10_algorithm - too many measurements in one day'
        caldat, daily[i].jd, m,d,y & print,y,m,d

     endif
     
  endfor

  
  return, daily
end
