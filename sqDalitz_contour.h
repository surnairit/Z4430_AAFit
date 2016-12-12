/*****************************************************************************
 * Project: RooFit                                                           *
 *                                                                           *
  * This code was autogenerated by RooClassFactory                            * 
 *****************************************************************************/

#ifndef SQDALITZ_CONTOUR
#define SQDALITZ_CONTOUR

#include "RooAbsPdf.h"
#include "RooRealProxy.h"
#include "RooCategoryProxy.h"
#include "RooAbsReal.h"
#include "RooAbsCategory.h"

#include "myPDF.h"
 
class sqDalitz_contour : public RooAbsPdf {
public:
  sqDalitz_contour() {} ; 
  sqDalitz_contour(const char *name, const char *title,
		 RooAbsReal& _mKP,
		 RooAbsReal& _cosKstar,
		 const Bool_t _massSquared,
		 const Int_t& _psi_nS
		 );
  sqDalitz_contour(const sqDalitz_contour& other, const char* name=0) ;
  virtual TObject* clone(const char* newname) const { return new sqDalitz_contour(*this,newname); }
  inline virtual ~sqDalitz_contour() { }

protected:

  RooRealProxy mKP ;
  RooRealProxy cosKstar ;
  
  Double_t evaluate() const ;

private:
  Bool_t massSquared;
  Int_t psi_nS;

  ClassDef(sqDalitz_contour,1) // Your description goes here...
};
 
#endif