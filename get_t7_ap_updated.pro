;+
;
; This is drop-in replacement for the old get_t7_ap.pro with new data
; sources. The Ap data source stopped updating 2018253 and F10 around
; there. This code called routines that download the data from LISIRD
; LaTiS and little a from the spaceweather data portal LaTiS.
;
; Requires IDLNetUrl objects to work.
;
; :Params:
;   yd: in, required, type=long
;     The 7-digit year and day of year to retrieve
;   f10: out, required, type=float
;     The 10.7 cm radio flux in SFU.
;   f10avg: out, required, type=float
;     The 81-day averaged of f10.7.
;   ap: out, optional, type=float
;     The daily average of A from Potsdam.
;
; :Keywords:
;   t7_last: out, optional, type=float
;     The last yyyydoy in the f10.7 time series.
;   ap_last: out, optional, type=float
;     The last yyyydoy in the ap timeseries.
;
; :Uses:
;   common_idx - a procedure to identify common indices in two arrays
;   download_f10 - download penticton & noaa f10 from LISIRD LaTiS
;                  merging the results and filtering radio bursts to
;                  create daily values
;   download_ap - download a index from SpWx Data Portal LaTiS and
;                  calculate Ap from 3 hour a values
; 
;-
pro get_t7_ap_updated, yd, f10, f10avg, ap, t7_last=t7_last, ap_last=ap_last, interp=interp

  common get_t7_ap_updated_cal, output, refreshtime, cal_t7_last, cal_ap_last

  thistime = systime(1) ; grab seconds counter from system clock
  reload = 1 ; assume reload

  
  ; if this is the first time, then load the data
  if size(output,/type) eq 0 then reload=1 else begin
     ; we know refreshtime was set in a previous call, and output is available
     ; only reload if data is over 12 hours old
     if thistime-refreshtime lt 12.*60*60 then reload=0 ; no need to reload
  endelse
  
  if reload eq 1 then begin

     refreshtime = systime(1)
  
     f10_history = download_f10()
     ap_history = download_ap()

     ; merged into one structure

     ; create a common structure, replicate it 
     ; populate it with data where it exists, interpolate where it doesn't
     tmpdays = [long(f10_history.jd),long(ap_history.jd)]
     uniqdays = tmpdays[uniq(tmpdays,sort(tmpdays))]

     fill = -1.d ; define a fill value for missing data
     rec = { jd: double(fill), $
             yyyymmdd: long(fill), $
             f10: float(fill), $
             f10avg: float(fill), $
             ap: float(fill) }
     output = replicate(rec, n_elements(uniqdays))

     common_idx, uniqdays, long(ap_history.jd), ui, ai
     output[ui].jd = ap_history[ai].jd
     output[ui].yyyymmdd = ap_history[ai].yyyymmdd
     output[ui].ap = ap_history[ai].ap

     common_idx, uniqdays, long(f10_history.jd), ui, fi
     output[ui].jd = f10_history.jd
     output[ui].f10 = f10_history.f10
     output[ui].f10avg = f10_history.f10a

     ; propagate backwards for f10 from 19470214 back to 1932001 for Ap
     firstf10idx = where(output.yyyymmdd eq 19470214)
     for i=firstf10idx[0],0,-1 do begin ; count backwards
        idx = i + (365L*11) ; add 11 year solar cycle
        output[i].f10 = output[idx].f10
        output[i].f10avg = output[idx].f10avg
     endfor
     
     ; fill missing data using interpolation
     interp=1
     if keyword_set(interp) then begin
        badap = where(output.ap lt -0.9,n_badap, comp=comp)
        output[badap].ap = interpol(output[comp].ap, output[comp].jd, $
                                    output[badap].jd)
        
        badf10 = where(output.f10 lt -0.9, n_badf10, comp=compf10)
        output[badf10].f10 = interpol(output[compf10].f10, output[compf10].jd, $
                                      output[badf10].jd)
        output[badf10].f10avg = interpol(output[compf10].f10avg, output[compf10].jd, $
                                         output[badf10].jd)
     endif

     ; Barry's code get_t7_ap also provides the last date as a yyyyddd
  
     caldat, f10_history[-1].jd, mo, da, year
     doy = f10_history[-1].jd - julday(1,1,year,12,0,0) + 1.
     cal_t7_last = long(year)*1000L + doy

     caldat, ap_history[-1].jd, mo, da, year
     doy = ap_history[-1].jd - julday(1,1,year,12,0,0) + 1.
     cal_ap_last = long(year)*1000L + doy

  endif ; end check for loaded data

  t7_last = cal_t7_last
  ap_last = cal_ap_last
  
  ; populate arguments with the appropriate values for f10 and ap
  argyear = long(yd) / 1000L
  argdoy = long(yd) mod 1000L
  thisjd = julday(1,1,argyear,12,0,0) + (argdoy - 1L) 
  idx = where(long(thisjd) eq long(output.jd), n_idx)
  f10idx = idx[0]
  apidx = idx[0]
  
  ;if n_idx eq 0 then begin
  ;   print,'WARNING: get_t7_ap_updated - did not locate jd in output structure'
  ;endif

  ; future (beyond end of dataset)
  if yd gt t7_last then begin
        ; Barry repeats the previous solar cycle for future dates
        ; assume exact 11 year solar cycle
     print,'WARNING: get_t7_ap_updated - '+strtrim(yd,2)+' is beyond the end of the historical record, wrapping to last solar cycle'
     proxyjd = round(thisjd)
     refjd = round(output[-1].jd)
     refidx = where(refjd eq round(output.jd))
     apidx = (refidx[0]-(11L*365L)) + ( (proxyjd - refjd) mod (11L*365L) )
     f10idx = apidx[0]
     apidx = apidx[0]
  endif
  
  ; past (before start of dataset)
  ; Barry uses the first 3 solar cycles and repeats them backwards leading
  ; to a big step in 19470213, a day prior to the first F10.7 day.
  if thisjd lt julday(1,1,1932) then begin
     print,'WARNING: get_t7_ap_updated - date is prior to Ap time record, repeating first solar cycle'
     proxyjd = thisjd
     refjd = round(julday(1,1,1932))
     refidx = where(refjd eq round(output.jd))
     apidx = refidx[0] + ( (refjd-proxyjd) mod (11.*365.) )
     apidx = apidx[0]
     f10idx = apidx[0]
  endif
  
  f10 = output[f10idx].f10
  f10avg = output[f10idx].f10avg
  ap = output[apidx].ap

  return
end
