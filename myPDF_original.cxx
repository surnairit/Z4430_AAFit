/***************************************************************************** 
 * Project: RooFit                                                           * 
 *                                                                           * 
 * This code was autogenerated by RooClassFactory                            * 
 *                                                                           *
 * A simple AA PDF class by Ivan Heredia de la Cruz on 4/25/16.              *
 *****************************************************************************/ 

#include "Riostream.h" 

#include "myPDF.h" 
#include "RooAbsReal.h" 
#include "RooAbsCategory.h" 
#include <math.h> 
#include "TMath.h" 



ClassImp(myPDF) 

 myPDF::myPDF(const char *name, const char *title, 
                        RooAbsReal& _mKp,
                        RooAbsReal& _cLb,
                        RooAbsReal& _cJ,
                        RooAbsReal& _cLs,
                        RooAbsReal& _phiMu,
                        RooAbsReal& _phiK,
                    RooAbsReal& _a1600L0S1,
                    RooAbsReal& _b1600L0S1,
                    RooAbsReal& _a1600L1S1,
                    RooAbsReal& _b1600L1S1,
                    RooAbsReal& _a1600L1S3,
                    RooAbsReal& _b1600L1S3,
                    RooAbsReal& _a1600L2S3,
                    RooAbsReal& _b1600L2S3,
                    RooAbsReal& _a1670L0S1,
                    RooAbsReal& _b1670L0S1,
                    RooAbsReal& _a1670L1S1,
                    RooAbsReal& _b1670L1S1,
                    RooAbsReal& _a1670L1S3,
                    RooAbsReal& _b1670L1S3,
                    RooAbsReal& _a1670L2S3,
                    RooAbsReal& _b1670L2S3
          ) :
   RooAbsPdf(name,title), 
   mKp("mKp","mKp",this,_mKp),
   cLb("cLb","cLb",this,_cLb),
   cJ("cJ","cJ",this,_cJ),
   cLs("cLs","cLs",this,_cLs),
   phiMu("phiMu","phiMu",this,_phiMu),
   phiK("phiK","phiK",this,_phiK),
a1600L0S1("a1600L0S1","a1600L0S1",this,_a1600L0S1),
b1600L0S1("b1600L0S1","b1600L0S1",this,_b1600L0S1),
a1600L1S1("a1600L1S1","a1600L1S1",this,_a1600L1S1),
b1600L1S1("b1600L1S1","b1600L1S1",this,_b1600L1S1),
a1600L1S3("a1600L1S3","a1600L1S3",this,_a1600L1S3),
b1600L1S3("b1600L1S3","b1600L1S3",this,_b1600L1S3),
a1600L2S3("a1600L2S3","a1600L2S3",this,_a1600L2S3),
b1600L2S3("b1600L2S3","b1600L2S3",this,_b1600L2S3),
a1670L0S1("a1670L0S1","a1670L0S1",this,_a1670L0S1),
b1670L0S1("b1670L0S1","b1670L0S1",this,_b1670L0S1),
a1670L1S1("a1670L1S1","a1670L1S1",this,_a1670L1S1),
b1670L1S1("b1670L1S1","b1670L1S1",this,_b1670L1S1),
a1670L1S3("a1670L1S3","a1670L1S3",this,_a1670L1S3),
b1670L1S3("b1670L1S3","b1670L1S3",this,_b1670L1S3),
a1670L2S3("a1670L2S3","a1670L2S3",this,_a1670L2S3),
b1670L2S3("b1670L2S3","b1670L2S3",this,_b1670L2S3)
 { 
 } 


 myPDF::myPDF(const myPDF& other, const char* name) :  
   RooAbsPdf(other,name), 
   mKp("mKp",this,other.mKp),
   cLb("cLb",this,other.cLb),
   cJ("cJ",this,other.cJ),
   cLs("cLs",this,other.cLs),
   phiMu("phiMu",this,other.phiMu),
   phiK("phiK",this,other.phiK),
a1600L0S1("a1600L0S1",this,other.a1600L0S1),
b1600L0S1("b1600L0S1",this,other.b1600L0S1),
a1600L1S1("a1600L1S1",this,other.a1600L1S1),
b1600L1S1("b1600L1S1",this,other.b1600L1S1),
a1600L1S3("a1600L1S3",this,other.a1600L1S3),
b1600L1S3("b1600L1S3",this,other.b1600L1S3),
a1600L2S3("a1600L2S3",this,other.a1600L2S3),
b1600L2S3("b1600L2S3",this,other.b1600L2S3),
a1670L0S1("a1670L0S1",this,other.a1670L0S1),
b1670L0S1("b1670L0S1",this,other.b1670L0S1),
a1670L1S1("a1670L1S1",this,other.a1670L1S1),
b1670L1S1("b1670L1S1",this,other.b1670L1S1),
a1670L1S3("a1670L1S3",this,other.a1670L1S3),
b1670L1S3("b1670L1S3",this,other.b1670L1S3),
a1670L2S3("a1670L2S3",this,other.a1670L2S3),
b1670L2S3("b1670L2S3",this,other.b1670L2S3)
 {

 }

 Double_t myPDF::evaluate() const 
 {

     // ENTER EXPRESSION IN TERMS OF VARIABLE ARGUMENTS HERE
     
     return myPDF::PDF();

 }

 Int_t myPDF::getAnalyticalIntegral(RooArgSet& allVars, RooArgSet& analVars, const char* ) const //rangeName
 { 
   // LIST HERE OVER WHICH VARIABLES ANALYTICAL INTEGRATION IS SUPPORTED, 
   // ASSIGN A NUMERIC CODE FOR EACH SUPPORTED (SET OF) PARAMETERS 
   // THE EXAMPLE BELOW ASSIGNS CODE 1 TO INTEGRATION OVER VARIABLE X
   // YOU CAN ALSO IMPLEMENT MORE THAN ONE ANALYTICAL INTEGRAL BY REPEATING THE matchArgs 
   // EXPRESSION MULTIPLE TIMES

    // if (matchArgs(allVars,analVars,mKp)) return 1 ;
    // if (matchArgs(allVars,analVars,mKp,cJ)) return 2 ;

     return 0 ;
 } 



 Double_t myPDF::analyticalIntegral(Int_t code, const char* rangeName) const  
 { 
   // RETURN ANALYTICAL INTEGRAL DEFINED BY RETURN CODE ASSIGNED BY getAnalyticalIntegral
   // THE MEMBER FUNCTION x.min(rangeName) AND x.max(rangeName) WILL RETURN THE INTEGRATION
   // BOUNDARIES FOR EACH OBSERVABLE x
     
//     if (code==1){
//         return 1;
//     }
//     if (code==2){
//         return 1;

     return 0 ;
 }




Double_t myPDF::cWignerDLb(string helLb, string helLs, string helJ) const
{
    
    if(helLb=="m1h" && helLs=="m1h" && helJ=="m1")
        return -TMath::Sin(TMath::ACos(cLb)/2.);
    else if(helLb=="m1h" && helLs=="m1h" && helJ=="0")
        return TMath::Cos(TMath::ACos(cLb)/2.);
    else if(helLb=="m1h" && helLs=="m1h" && helJ=="p1")
        return 0.0;
    else if(helLb=="m1h" && helLs=="p1h" && helJ=="m1")
        return 0.0;
    else if(helLb=="m1h" && helLs=="p1h" && helJ=="0")
        return -TMath::Sin(TMath::ACos(cLb)/2.);
    else if(helLb=="m1h" && helLs=="p1h" && helJ=="p1")
        return TMath::Cos(TMath::ACos(cLb)/2.);
    else if(helLb=="m1h" && helLs=="p3h" && helJ=="p1")
        return -TMath::Sin(TMath::ACos(cLb)/2.);
    else if(helLb=="p1h" && helLs=="m1h" && helJ=="m1")
        return TMath::Cos(TMath::ACos(cLb)/2.);
    else if(helLb=="p1h" && helLs=="m1h" && helJ=="0")
        return TMath::Sin(TMath::ACos(cLb)/2.);
    else if(helLb=="p1h" && helLs=="m1h" && helJ=="p1")
        return 0.0;
    else if(helLb=="p1h" && helLs=="p1h" && helJ=="m1")
        return 0.0;
    else if(helLb=="p1h" && helLs=="p1h" && helJ=="0")
        return TMath::Cos(TMath::ACos(cLb)/2.);
    else if(helLb=="p1h" && helLs=="p1h" && helJ=="p1")
        return TMath::Sin(TMath::ACos(cLb)/2.);
    else return 0.0;

}


TComplex myPDF::cWignerDLsSpinOneHalf(string helLs, string help) const
{
    
    if(helLs=="m1h" && help=="m1h")
        return -(TComplex::Exp((TComplex::I()*phiK)/2.)*TMath::Sin(TMath::ACos(cLs)/2.));
    else if(helLs=="m1h" && help=="p1h")
        return TComplex::Exp((TComplex::I()*phiK)/2.)*TMath::Cos(TMath::ACos(cLs)/2.);
    else if(helLs=="p1h" && help=="m1h")
        return TMath::Cos(TMath::ACos(cLs)/2.)/TComplex::Exp((TComplex::I()*phiK)/2.);
    else if(helLs=="p1h" && help=="p1h")
        return TMath::Sin(TMath::ACos(cLs)/2.)/TComplex::Exp((TComplex::I()*phiK)/2.);
    else
        return 0;
    
}


TComplex myPDF::cWignerDJ(string helJ, string helDmu) const
{
 
    if(helJ=="m1" && helDmu=="m1")
        return ((1. + cJ)*TComplex::Exp(TComplex::I()*phiMu))/2.;
    else if(helJ=="m1" && helDmu=="p1")
        return -((-1. + cJ)*TComplex::Exp(TComplex::I()*phiMu))/2.;
    else if(helJ=="0" && helDmu=="m1")
        return TMath::Sqrt(1. - TMath::Power(cJ,2))/TMath::Sqrt2();
    else if(helJ=="0" && helDmu=="p1")
        return -(TMath::Sqrt(1. - TMath::Power(cJ,2))/TMath::Sqrt2());
    else if(helJ=="p1" && helDmu=="m1")
        return -(-1. + cJ)/(2.*TComplex::Exp(TComplex::I()*phiMu));
    else if(helJ=="p1" && helDmu=="p1")
        return (1. + cJ)/(2.*TComplex::Exp(TComplex::I()*phiMu));
    else
        return 0;

}


Double_t myPDF::Pmom(Double_t mkp) const
{
 
    Double_t mkp2 = mkp*mkp;
    Double_t rootterm = MJPsi4mTwoMJPsi2MLb2pMLb4 + mkp2*(mkp2 - TwoMJPsi2pTwoMLb2);
    if (rootterm > 0)
        return InvTwoMLb*TMath::Sqrt(rootterm);
    
    return 0.;
}

Double_t myPDF::Qmom(Double_t mkp) const
{
    
    Double_t mkp2 = mkp*mkp;
    Double_t rootterm = MKaon4mTwoMKaon2MProton2pMProton4 + mkp2*(mkp2 - TwoMKaon2pTwoMProton2) ;
    if (rootterm > 0)
        return 0.5*TMath::Sqrt(rootterm)/mkp;
    
    return 0.;
}


Double_t myPDF::PhiPHSP(Double_t mkp) const
{
    return myPDF::Pmom(mkp) * myPDF::Qmom(mkp) ;
}


Double_t myPDF::BlattWeisskopf(Int_t Lmin, Double_t q, Double_t q0, Double_t D) const
{
    Double_t Dq = D*q;
    Double_t Dq0 = D*q0;
    Double_t Dq2 = Dq*Dq;
    Double_t Dq02 = Dq0*Dq0;
    Double_t rootterm;
    
    if(Lmin==0)
        return  1.;
    else if(Lmin==1)
        rootterm = (1. + Dq02)/(1. + Dq2) ;
    else
        return 1. ;
    
    if (rootterm > 0)
        return TMath::Sqrt( rootterm );
    else
        return 1. ;
}

Double_t myPDF::BWGamma(Double_t RMass, Double_t RGamma, Int_t Lmin, Double_t D) const
{

    Double_t QmKp = myPDF::Qmom(mKp);
    Double_t QRMass = myPDF::Qmom(RMass);
    Int_t expoterm = 2*Lmin + 1 ;

    return ( RGamma * RMass * TMath::Power(QmKp/QRMass,expoterm) * TMath::Power(myPDF::BlattWeisskopf(Lmin, QmKp, QRMass, D),2) ) / mKp ;
    
}

TComplex myPDF::BW(Double_t RMass, Double_t RGamma, Int_t Lmin, Double_t D) const
{

    Double_t num1term = RMass*RMass - mKp*mKp ;
    Double_t num2term = RMass * myPDF::BWGamma(RMass, RGamma, Lmin, D) ;
    Double_t denoterm = num1term*num1term + num2term*num2term ;

    return TComplex(num1term / denoterm, num2term / denoterm) ;
    
}

TComplex myPDF::RFunction(Double_t RMass, Double_t RGamma, Int_t LminLb, Int_t LminLs, Double_t D) const
{
    
    Double_t PmKp = myPDF::Pmom(mKp);
    Double_t PRMass = myPDF::Pmom(RMass);
    Double_t QmKp = myPDF::Qmom(mKp);
    Double_t QRMass = myPDF::Qmom(RMass);
    
    return myPDF::BlattWeisskopf(LminLb, PmKp, PRMass, D) * TMath::Power(PmKp/MLb,LminLb) * myPDF::BW(RMass, RGamma, LminLs, D) * myPDF::BlattWeisskopf(LminLs, QmKp, QRMass, D) * TMath::Power(QmKp/RMass,LminLs) ;
    
    
}

TComplex myPDF::Cterm(string helLs, string helJ, string help) const
{
    if ( (helLs=="p1h" && helJ=="p1") || (helLs=="p1h" && helJ=="0") || (helLs=="m1h" && helJ=="0") || (helLs=="m1h" && helJ=="m1") )
    {

        TComplex sum1h = myPDF::HLb1670(helLs, helJ) * myPDF::HLs1670(help) * myPDF::RFunction(M1670, G1670, 0, 0, dRad) + myPDF::HLb1600(helLs, helJ) * myPDF::HLs1600(help) * myPDF::RFunction(M1600, G1600, 0, 1, dRad) ;
            
        return sum1h * myPDF::cWignerDLsSpinOneHalf(helLs, help) ;
        
    }

    return 0.;
}


TComplex myPDF::Cfterm(string helLs, string helJ, string help, string helDmu) const
{
    
    
    return myPDF::Cterm(helLs, helJ, help) *  myPDF::cWignerDJ(helJ, helDmu) ;
    
}


TComplex myPDF::ME(string helLb, string help, string helDmu ) const
{
    
    return
    myPDF::Cfterm("m1h", "m1", help, helDmu) * myPDF::cWignerDLb(helLb, "m1h", "m1") +
    myPDF::Cfterm("m1h", "0",  help, helDmu) * myPDF::cWignerDLb(helLb, "m1h", "0") +
    myPDF::Cfterm("m1h", "p1", help, helDmu) * myPDF::cWignerDLb(helLb, "m1h", "p1") +
    myPDF::Cfterm("p1h", "m1", help, helDmu) * myPDF::cWignerDLb(helLb, "p1h", "m1") +
    myPDF::Cfterm("p1h", "0",  help, helDmu) * myPDF::cWignerDLb(helLb, "p1h", "0") +
    myPDF::Cfterm("p1h", "p1", help, helDmu) * myPDF::cWignerDLb(helLb, "p1h", "p1") 
    ;
    
}


TComplex myPDF::ME2() const
{

    TComplex MEm1hm1hm1 = myPDF::ME("m1h", "m1h", "m1");
    TComplex MEm1hm1hp1 = myPDF::ME("m1h", "m1h", "p1");
    TComplex MEm1hp1hm1 = myPDF::ME("m1h", "p1h", "m1");
    TComplex MEm1hp1hp1 = myPDF::ME("m1h", "p1h", "p1");

    TComplex MEp1hm1hm1 = myPDF::ME("p1h", "m1h", "m1");
    TComplex MEp1hm1hp1 = myPDF::ME("p1h", "m1h", "p1");
    TComplex MEp1hp1hm1 = myPDF::ME("p1h", "p1h", "m1");
    TComplex MEp1hp1hp1 = myPDF::ME("p1h", "p1h", "p1");

    
    return
    MEm1hm1hm1*TComplex::Conjugate(MEm1hm1hm1) +
    MEm1hm1hp1*TComplex::Conjugate(MEm1hm1hp1) +
    MEm1hp1hm1*TComplex::Conjugate(MEm1hp1hm1) +
    MEm1hp1hp1*TComplex::Conjugate(MEm1hp1hp1) +
    MEp1hm1hm1*TComplex::Conjugate(MEp1hm1hm1) +
    MEp1hm1hp1*TComplex::Conjugate(MEp1hm1hp1) +
    MEp1hp1hm1*TComplex::Conjugate(MEp1hp1hm1) +
    MEp1hp1hp1*TComplex::Conjugate(MEp1hp1hp1)
    ;

}

TComplex myPDF::PDF() const
{
    
    return myPDF::ME2() * myPDF::PhiPHSP(mKp);

}



TComplex myPDF::HLb1600(string helLs, string helJ) const
{
    
    if(helLs=="m1h" && helJ=="m1")
        return (-2.*a1600L0S1 + 2.*a1600L1S1 - TMath::Sqrt2()*a1600L1S3 + TMath::Sqrt2()*a1600L2S3 + TComplex::I()*(-2.*b1600L0S1 + 2.*b1600L1S1 + TMath::Sqrt2()*(-b1600L1S3 + b1600L2S3)))/(2.*TMath::Sqrt(3.));
    else if(helLs=="m1h" && helJ=="0")
        return -(TMath::Sqrt2()*a1600L0S1 + TMath::Sqrt2()*a1600L1S1 + 2.*a1600L1S3 + 2.*a1600L2S3 + TComplex::I()*(TMath::Sqrt2()*b1600L0S1 + TMath::Sqrt2()*b1600L1S1 + 2.*(b1600L1S3 + b1600L2S3)))/(2.*TMath::Sqrt(3.));
    else if(helLs=="m1h" && helJ=="p1")
        return 0.;
    else if(helLs=="p1h" && helJ=="m1")
        return 0.;
    else if(helLs=="p1h" && helJ=="0")
        return (TMath::Sqrt2()*(a1600L0S1 - a1600L1S1) + 2.*(a1600L2S3 - a1600L1S3) + TComplex::I()*(TMath::Sqrt2()*(b1600L0S1 - b1600L1S1)  + 2.*(b1600L2S3 - b1600L1S3)))/(2.*TMath::Sqrt(3.));
    else if(helLs=="p1h" && helJ=="p1")
        return (2.*a1600L0S1 + 2.*a1600L1S1 - TMath::Sqrt2()*a1600L1S3 - TMath::Sqrt2()*a1600L2S3 + TComplex::I()*(2.*b1600L0S1 + 2.*b1600L1S1 - TMath::Sqrt2()*(b1600L1S3 + b1600L2S3)))/(2.*TMath::Sqrt(3.));
    else
        return 0.;
    
}


TComplex myPDF::HLb1670(string helLs, string helJ) const
{
    
    if(helLs=="m1h" && helJ=="m1")
        return (-2.*a1670L0S1 + 2.*a1670L1S1 - TMath::Sqrt2()*a1670L1S3 + TMath::Sqrt2()*a1670L2S3 + TComplex::I()*(-2.*b1670L0S1 + 2.*b1670L1S1 + TMath::Sqrt2()*(-b1670L1S3 + b1670L2S3)))/(2.*TMath::Sqrt(3.));
    else if(helLs=="m1h" && helJ=="0")
        return -(TMath::Sqrt2()*a1670L0S1 + TMath::Sqrt2()*a1670L1S1 + 2.*a1670L1S3 + 2.*a1670L2S3 + TComplex::I()*(TMath::Sqrt2()*b1670L0S1 + TMath::Sqrt2()*b1670L1S1 + 2.*(b1670L1S3 + b1670L2S3)))/(2.*TMath::Sqrt(3.));
    else if(helLs=="m1h" && helJ=="p1")
        return 0.;
    else if(helLs=="p1h" && helJ=="m1")
        return 0.;
    else if(helLs=="p1h" && helJ=="0")
        return (TMath::Sqrt2()*(a1670L0S1 - a1670L1S1) + 2.*(a1670L2S3 - a1670L1S3) + TComplex::I()*(TMath::Sqrt2()*(b1670L0S1 - b1670L1S1)  + 2.*(b1670L2S3 - b1670L1S3)))/(2.*TMath::Sqrt(3.));
    else if(helLs=="p1h" && helJ=="p1")
        return (2.*a1670L0S1 + 2.*a1670L1S1 - TMath::Sqrt2()*a1670L1S3 - TMath::Sqrt2()*a1670L2S3 + TComplex::I()*(2.*b1670L0S1 + 2.*b1670L1S1 - TMath::Sqrt2()*(b1670L1S3 + b1670L2S3)))/(2.*TMath::Sqrt(3.));
    else
        return 0.;
    
}


Double_t myPDF::HLs1600(string help) const
{
    
    if(help=="m1h")
        return -1.;
    else if(help=="p1h")
        return 1.;
    else
        return 0;
    
}

Double_t myPDF::HLs1670(string help) const
{
    
    if(help=="m1h")
        return 1.;
    else if(help=="p1h")
        return 1.;
    else
        return 0;
    
}



