pro test_get_t7_ap

  yd=1947044
  for i=0,100 do begin
     get_t7_ap_updated, yd, f10, f10avg, ap
     get_t7_ap, yd+1.d, ft7p_auto, ft7a_auto, ap_auto
     print, yd, f10, ft7p_auto, f10/ft7p_auto
     yd++
  endfor
  ;stop

  ; test get_t7_ap and a replacement function get_t7_ap_updated
  ; that uses download_f10 and download_ap functions
  ; that rely on using IDLNetURL

;  ydlist = (lindgen(21)+2002L)*1000L + 1L ; jan 1 for each year 2002-2022
  ydlist=[1930001, 1945001, 1947045, 2022001]
  compare_rec = {yd:0L, f10:0., ft7p_auto:0., f10avg:0., ft7a_auto:0., ap:0., ap_auto:0.}
  compare = replicate( compare_rec, round(365.25*123) ) ; 1900-2023

  tyd = 1900001L
  index=0L
  while index le n_elements(compare)-1 do begin

                                ; It looks like Barry's code is
                                ; off by one day, add one day to the call

     ; Barry's code says Ap is the Fredericksburg Ap
     get_t7_ap, tyd+1, ft7p_auto, ft7a_auto, ap_auto

     ; replacement code
     get_t7_ap_updated, tyd, f10, f10avg, ap

     compare[index].yd = tyd
     compare[index].ft7p_auto = ft7p_auto
     compare[index].ft7a_auto = ft7a_auto
     compare[index].ap_auto = ap_auto
     compare[index].f10 = f10
     compare[index].f10avg = f10avg
     compare[index].ap = ap
     ;stop
     index++
     tyd = get_next_yyyydoy(tyd)
  endwhile
  gd=where(compare.yd gt 1) & compare=compare[gd]
  
  yf = yd_to_yfrac(compare.yd)
  !p.multi=[0,1,2]
  !p.charsize=1.5 & !p.color=0 & !p.background='ffffff'x
  ; f10
  plot, yf, compare.ft7p_auto, xr=[1900,2000],xs=1,ys=1,xtit='Year',tit='F10.7 compare get_t7_ap & update',ytit='SFU'
  wdelete
  !p.multi=[0,1,2]
  !p.charsize=1.5 & !p.color=0 & !p.background='ffffff'x
  plot, yf, compare.ft7p_auto, xr=[1900,2000],xs=1,ys=1,xtit='Year',tit='F10.7 compare get_t7_ap & update',ytit='SFU'
  oplot, yf, compare.f10, co='fe'x
  oplot, yd_to_yfrac(1947045)*[1,1],!y.crange,lines=2,co='cc00'x
  xyouts,/norm,.1,.95,'Old'
  xyouts,/norm,.15,.95,'New',co='fe'x

  diff = compare.ft7p_auto - compare.f10
  percent = (diff / compare.f10)*100.

  plot, yf, diff, xr=!x.crange,xs=1,ys=1,xtit='Year',tit='F10.7 difference get_t7_ap - update',ytit='SFU',yr=[-100,100]
  stop
  
  plot, yf, compare.ft7p_auto, xr=[2000,2025],xs=1,ys=1,xtit='Year',tit='F10.7 compare get_t7_ap & update',ytit='SFU'
  oplot, yf, compare.f10, co='fe'x
  xyouts,/norm,.1,.95,'Old'
  xyouts,/norm,.15,.95,'New',co='fe'x
  plot, yf, compare.ft7p_auto - compare.f10, xr=!x.crange,xs=1,ys=1,xtit='Year',tit='F10.7 difference get_t7_ap - update',ytit='SFU',yr=[-100,100]
  stop

  plot, yf, compare.ft7p_auto, xr=[1947,1947.5],xs=1,ys=1,xtit='Year',tit='F10.7 compare get_t7_ap & update',ytit='SFU'
  oplot, yf, compare.f10, co='fe'x,ps=-1
  xyouts,/norm,.1,.95,'Old'
  xyouts,/norm,.15,.95,'New',co='fe'x
  plot, yf, percent, yr=[-10,10], ys=1,xr=[1947,2025],xs=1,xtit='Year',tit='F10.7 percent difference',ytit='SFU'
  stop
  
  ; f10avg
  !p.multi=[0,1,2]
  plot, yf, compare.ft7a_auto, xr=[1900,2000],xs=1,ys=1,xtit='Year',tit='F10.7avg compare get_t7_ap & update',ytit='SFU'
  oplot, yf, compare.f10avg, co='fe'x
  xyouts,/norm,.1,.95,'Old'
  xyouts,/norm,.15,.95,'New',co='fe'x
  plot, yf, compare.ft7a_auto, xr=[2000,2025],xs=1,ys=1,xtit='Year',tit='F10.7avg compare get_t7_ap & update',ytit='SFU'
  oplot, yf, compare.f10avg, co='fe'x
  stop

  ; Ap
  !p.multi=[0,1,2]
  plot, yf, compare.ap_auto, xr=[1900,2000],xs=1,ys=1,xtit='Year',tit='Ap compare get_t7_ap & update',ytit='Ap (2nT)'
  oplot, yf, compare.ap, co='fe'x
  xyouts,/norm,.1,.95,'Old'
  xyouts,/norm,.15,.95,'New',co='fe'x
  plot, yf, compare.ap_auto, xr=[2000,2025],xs=1,ys=1,xtit='Year',tit='Ap compare get_t7_ap & update',ytit='Ap (2nT)'
  oplot, yf, compare.ap, co='fe'x
  stop
  
  stop
  for i=0,n_elements(ydlist)-1 do begin

     get_t7_ap, ydlist[i], ft7p_auto, ft7a_auto, ap_auto, $
                t7_last=t7_last, ap_last=ap_last
                                ; NCEI site says Ap comes from
                                ; Potsdam, that's where SpWx
                                ; Data portal get it, too
     get_t7_ap_updated, ydlist[i], f10, f10avg, ap, $
                        t7_last=f10lastupdated, ap_last=aplastupdated
     print,strtrim(ydlist[i],2),$
           ' ft7p_auto=', string(ft7p_auto, form='(f5.1)'),$
           ' f10=', string(f10, form='(f5.1)'), $
           ' ft7a_auto=', string(ft7a_auto, form='(f5.1)'),$
           ' f10avg=', string(f10avg, form='(f5.1)')
     print,' ap_auto=', string(ap_auto, form='(f4.1)'), $
           ' ap=', string(ap, form='(f4.1)')
     stop
     
  endfor
  
  stop
  return
end
