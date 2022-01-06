;+
; This function retrieve the argumment URL contents
; as a string array. You can provide any HTTPS URL and this returns
; the strings that would be sent to a web browser for parsing.
;
; :Params:
;    url: in, required, type=string
;      The restful string to request e.g. for LISIRD LATIS use
;      something like 'https://lasp.colorado.edu:80/lisird/latis/dap/sorce_ssi.csv?time,irradiance&time>=2017-01-20&format_time(yyyyDDD)&wavelength=121.5'
;
; :Returns:
;    This returns a string array of html that you would get from a web
;    browser pointing at the provided URL.
;
;-
function latis_geturlasstring, url

  catch, errorstatus
  if (errorstatus ne 0) then begin
     catch,/cancel
     oURL->getproperty,response_code=respcode, response_header=hdr
     print,'ERROR: latis_geturlasstring encountered an error and cannot continue'
     print,'***An error has occurred trying to contact LATIS***'
     print,'*** respose code='+strtrim(respcode,2)+' ***'
     print,'*** response header='+strtrim(hdr,2)+' ***'
     obj_destroy,oURL
     return,''
  endif

  oURL = OBJ_NEW('IDLnetURL')
  oURL->SetProperty,SSL_VERIFY_PEER=0 ; 5/5/21 prevent SSL CA cert issues (code=60)
  print,'calling URL = '+url
  str = oURL->Get(URL=url, /string_array) ; store result in a string array
  oURL->CloseConnections ; need to close the connection in the IDLNetURL object
  OBJ_DESTROY, oURL ; cleanup to prevent memory leaks

  if n_elements(str) lt 2 then begin
     print,'WARNING: latis_geturlasstring - not much returned from url '+url
  endif
  heap_gc ; force garbage cleanup
  
return,str
end

