#include <cuda_runtime.h>
#include "Variable.hh"
#include "ThreeBodiesPsiPiKPdf.hh"
#include "FitManager.hh"
#include "UnbinnedDataSet.hh"
#include "BinnedDataSet.hh"
#include "FlatHistoPdf.hh"
#include "AddPdf.hh"
#include "ProdPdf.hh"
#include "MatrixPdf.hh"

#include "TNtupleD.h"
#include "TTree.h"
#include "TCanvas.h"
#include "TGraph.h"
#include "TH1F.h"
#include "TH2F.h"
#include "TColor.h"
#include "TString.h"
#include "TH1.h"
#include "TColor.h"
#include "TAxis.h"
#include "TROOT.h"
#include "TFile.h"
#include "TMath.h"
#include "TRandom.h"
#include "TMultiGraph.h"
#include "TPaveText.h"
#include "TAttLine.h"
#include "TGraph2D.h"
#include "TLegend.h"
#include "TSystem.h"
#include "TStyle.h"

#include "BiDimHistoPdf.hh"

#include "../utilities.h"
// #include "../Angles_contour.h"
// #include "../Dalitz_contour.h"
// #include "../effMasses.h"

#include <vector>
#include <string>
#include <map>
#include <math.h>
#include <sstream>
#include <utility> // std::make_pair
#include <fstream>
#include <iomanip> // std::setprecision

#include <sys/time.h> // for timeval
#include <sys/times.h> // for tms
#include <iostream>

#include <thrust/host_vector.h>
#include <thrust/device_vector.h>

//#define CUDADEBUGGING 50


timeval startTime, stopTime, totalTime;
clock_t startC, stopC;
tms startProc, stopProc;

const fptype M892e = 0.8961 ; const fptype G892e = 0.0507; // From EvtGen

const fptype TMATH_PI = TMath::Pi();

std::string migrad("MIGRAD"); std::string m("M");
std::string hesse("HESSE");   std::string h("H");
std::string minos("MINOS");   std::string n("N");

bool debugging = false;


fptype phaseSpaceFunction(fptype x,fptype mP,fptype m1,fptype m2,fptype m3)
{
  fptype value = sqrt(pow(x,4) + pow(m1,4) + pow(m2,4) - 2*pow(x,2)*pow(m1,2) - 2*pow(x,2)*pow(m2,2) - 2*pow(m1,2)*pow(m2,2)) * sqrt(pow(mP,4) + pow(x,4) + pow(m3,4) - 2*pow(mP,2)*pow(x,2) - 2*pow(mP,2)*pow(m3,2) - 2*pow(x,2)*pow(m3,2) ) / (x) ;

  fptype function = isnan(value) ? 0 : value;

  return function;
}

void debug(int line) {
  if (debugging)
    std::cout <<"Debugging on line " <<line <<std::endl;
}

int parDotSpin (fptype dotSpin) {
  int result = static_cast<int>(floor((dotSpin - floor(dotSpin))*10.+.1));
  return result;
}

std::string doubleToStr (fptype dbl) {
  std::ostringstream strs;
  strs <<dbl;
  return strs.str();
}

Int_t compBins = 50, pdfBins = 50, dataBins = 100;
//Int_t compBins = 100, pdfBins = 100, dataBins = 100;

void addHelAmplStat(TPaveText *fitStat, TString hel, Variable* a, Variable* b) {
  TString a_value = TString::Format("a_{%s} = %.2f",hel.Data(),a->value) ;
  TString a_error = TString::Format("#pm %.2f",a->error) ;
  if (a->fixed) a_error = "fixed";

  TString b_value = TString::Format("b_{%s} = %.2f",hel.Data(),b->value) ;
  TString b_error = TString::Format("#pm %.2f",b->error) ;
  if (b->fixed) b_error = "fixed";

  fitStat->AddText(TString::Format("%s %s, %s %s",a_value.Data(),a_error.Data(),b_value.Data(),b_error.Data()));
}

void printCodes()
{
  std::cerr <<"Codes" <<std::endl;
}

int checkGPU()
{
    int deviceCount, device;
    int gpuDeviceCount = 0;
    struct cudaDeviceProp properties;
    cudaError_t cudaResultCode = cudaGetDeviceCount(&deviceCount);
    if (cudaResultCode != cudaSuccess)
        deviceCount = 0;
    for (device = 0; device < deviceCount; ++device) {
        cudaGetDeviceProperties(&properties, device);
        if (properties.major != 9999) /* 9999 means emulation only */
            ++gpuDeviceCount;
    }
    printf("%d GPU CUDA device(s) found\n", gpuDeviceCount);

    if (gpuDeviceCount > 0)
        return 0; /* success */
    else
        return 1; /* failure */
}

void printinstruction() {

  std::cerr <<"======= Instructions \n"
	    <<"\t-h,--help \t\t Show this help message\n"
            <<"\t-evtGen \t\t Select EvtGen dataset and p.d.f. parameters\n"
            <<"\t-effH \t\t\t Perform the product of the pdf by the efficiency histogram \n"
            <<"\t-effHInt \t\t Perform the product of the pdf by the efficiency histogram interpolation \n"
            <<"\t-BkgMap \t\t Add Phase Space Background Map \n"
            <<"\t-BkgMapInt \t\t Add Phase Space Background Interpolation Map \n"
            <<"\t-BkgPHSP \t\t Add Phase Space Background to p.d.f.\n"
            //<<"\t-effH <4-dig-code> \t Perform the product of the pdf by the efficiency histogram ()\n"
            //<<"\t\t\t\t\t\t - code1 ()\n"
	    <<"\t-n <events> \t\t Specify the number of events to use\n"
	    <<"\t-r <path> \t\t Read Generated Events from txt in <path>\n"
            <<"\t-o <path> \t\t Write estimated parameters in \" parameters.txt \" file in <path> (default . )\n"
            <<"\t-algos <Algo1Algo2...>\t Select the mimimisation algos in the order they should \n \t\t\t\t be performed (MIGRAD at least once) ["<<m<<" for MIGRAD, "<<h<<" for HESSE, "<<n<<" for MINOS]\n \t\t\t\t (e.g -algo "<<h<<m<<h<<n<<" for HESSE MIGRAD HESSE MINOS - default: MIGRAD only) \n"
	    <<"\t-b1 <b1> \t\t Select binning for MassKPi (for normalisation & integration, default: " <<compBins <<")\n"
            <<"\t-b2 <b2> \t\t Select binning for MassPsiPi (for normalisation & integration, default: " <<compBins <<")\n"
            <<"\t-b3 <b3> \t\t Select binning for CosMuMu (for normalisation & integration, default: " <<compBins <<")\n"
            <<"\t-b4 <b4> \t\t Select binning for Phi (for normalisation & integration, default: " <<compBins <<")\n"
            <<"\t-hPlots  \t\t Draw p.d.f.s as histograms instead of continous lines \n"
            <<"\t-p1 <p> \t\t Select p.d.f. plotting binning finenness (default: " <<pdfBins <<") for MassKPi \n"
            <<"\t-p2 <p> \t\t Select p.d.f. plotting binning finenness (default: " <<pdfBins <<") for MassPsiPi \n"
            <<"\t-p3 <p> \t\t Select p.d.f. plotting binning finenness (default: " <<pdfBins <<") for CosMuMu \n"
            <<"\t-p4 <p> \t\t Select p.d.f. plotting binning finenness (default: " <<pdfBins <<") for Phi \n"
            <<"\t-d1 <p> \t\t Select dataset binning (default: " <<dataBins <<") for MassKPi \n"
            <<"\t-d2 <p> \t\t Select dataset binning (default: " <<dataBins <<") for MassPsiPi \n"
            <<"\t-d3 <p> \t\t Select dataset binning (default: " <<dataBins <<") for CosMuMu \n"
            <<"\t-d4 <p> \t\t Select dataset binning (default: " <<dataBins <<") for Phi \n"
            <<"\t-Bb <Bb> \t\t Select bound limits for b parameter (default: 9999)\n"
            <<"\t-k800 \t\t\t Add K*_0(800) to p.d.f.\n"
            <<"\t-k892 \t\t\t Add K*_1(892) to p.d.f.\n"
            <<"\t-k1410 \t\t\t Add K*_1(1410) to p.d.f.\n"
            <<"\t-k1430_0 \t\t Add K*_0(1430) to p.d.f.\n"
            <<"\t-k1430_2 \t\t Add K*_2(1430) to p.d.f.\n"
            <<"\t-k1780 \t\t\t Add K*_3(1780) to p.d.f.\n"
            <<"\t-b0Var \t\t\t Add B0 - B0Bar flag as variable for each event candidate \n \t\t\t\t (Incompatible with -b0Var) \n"
            <<"\t-b0BarPdf \t\t Use B0Bar p.d.f. instead of B0 p.d.f. \n \t\t\t\t (Incompatible with -b0Var)\n"
            <<"\t-b0Flag \t\t Add B0 - B0Bar flag: multplying phi by -1\n"
            <<"\t-b0Bar  \t\t B0Bar dataset instead of B0 \n"
            <<"\t-fixA <code> \t\t Fix K* p.d.f. amplitudes to starting values (option -fixH to read codes) \n"
            <<"\t-fixB <code> \t\t Fix K* p.d.f. phases to starting values (option -fixH to read codes)\n"
            <<std::endl;
}


int main(int argc, char** argv) {

  gStyle->SetOptStat(000000000);

  if(checkGPU())
  {
    std::cerr<<"NO Cuda capable device found. Returning.\n"<<std::endl;
    return 1;
  }

  debug(__LINE__);

  char bufferstring[1024];

  unsigned int events = 100000;
  unsigned int nKstars = 0;

  vector <Int_t> bin; // same order as varNames
  bin.push_back(compBins); bin.push_back(compBins); bin.push_back(compBins); bin.push_back(compBins);
  vector <Int_t> dataPoints; // same order as varNames
  dataPoints.push_back(dataBins); dataPoints.push_back(dataBins); dataPoints.push_back(dataBins); dataPoints.push_back(dataBins);
  vector <Int_t> plottingFine; // same order as varNames
  plottingFine.push_back(pdfBins*4); plottingFine.push_back(pdfBins); plottingFine.push_back(pdfBins); plottingFine.push_back(pdfBins);

  fptype aMax = +9999.;
  fptype bMax = +9999.;

  bool k892Star = false, k800Star = false, k1410Star = false, k1430Star0 = false, k1430Star2 = false, k1780Star = false;

  bool b0Var = false;
  bool b0Flag = false;
  bool b0Bar = false;
  bool b0BarPdf = false;

  bool bkgFlag = false;
  bool bkgPhaseSpace = false;

  bool bkgHist = false;
  bool bkgHistMap = false;
  bool bkgHistInt = false;


  bool effPdfProd = false;
  bool effPdfInter = false;
  bool effPdfFlat = false;

  bool evtGen = false;

  bool txtfile = false;
  bool outParams = false;

  bool hPlots = false;

  bool localRead = false;

  bool aFix = false;
  bool bFix = false;
  //bool hesse = false;

  std::vector<std::string> algos;
  algos.push_back(migrad);

  std::string outPath;
  std::string inPath;

  std::string aFixCode;
  std::string bFixCode;

  TString datasetName = "Kstars";
  std::string underscores = "__";
  TString plotsDir = "./plots";
  std::vector< std::string> kStarNames;
  TString plotOption = "L";

  TH2F* relEffTH2Mass = 0 , *relEffTH2Ang = 0;
  TH2F relEffTH2[2], bkgTH2[2];
  TH2F* bkgTH2Mass = 0, *bkgTH2Ang = 0;

  TH1D* bkgHistos[] = {0,0,0,0};

  if (argc<=1) {
    printinstruction();
    return 0;
  }

  for (int i = 1; i < argc; ++i) {
    std::string arg = argv[i];

    if ((arg == "-h") || (arg == "--help")) {
      printinstruction();
      return 0;
    }
    else if (arg == "-n") {
      if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	i++;
	std::istringstream ss(argv[i]);
	if (!(ss >> events)) {
	  std::cerr <<"Invalid number " <<argv[i] <<'\n';
	  exit(1); }
      } }
    else if (arg == "-r") {
      if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	i++;
	txtfile = true;
	inPath = argv[i];
      } }
    else if (arg == "-b1") {
      if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	i++;
	std::istringstream ss(argv[i]);
	if (!(ss >> bin[0])) {
	  std::cerr <<"Invalid number " <<argv[i] <<'\n';
	  exit(1); }
      } }
    else if (arg == "-b2") {
      if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	i++;
	std::istringstream ss(argv[i]);
	if (!(ss >> bin[1])) {
	  std::cerr <<"Invalid number " <<argv[i] <<'\n';
	  exit(1); }
      } }
    else if (arg == "-b3") {
      if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	i++;
	std::istringstream ss(argv[i]);
	if (!(ss >> bin[2])) {
	  std::cerr <<"Invalid number " <<argv[i] <<'\n';
	  exit(1); }
      } }
    else if (arg == "-b4") {
      if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	i++;
	std::istringstream ss(argv[i]);
	if (!(ss >> bin[3])) {
	  std::cerr <<"Invalid number " <<argv[i] <<'\n';
	  exit(1); }
      } }
    else if (arg == "-p1") {
      if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	i++;
	std::istringstream ss(argv[i]);
	if (!(ss >> plottingFine[0])) {
	  std::cerr <<"Invalid number " <<argv[i] <<'\n';
	  exit(1); }
      } }
    else if (arg == "-p2") {
      if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	i++;
	std::istringstream ss(argv[i]);
	if (!(ss >> plottingFine[1])) {
	  std::cerr <<"Invalid number " <<argv[i] <<'\n';
	  exit(1); }
      } }
    else if (arg == "-p3") {
      if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	i++;
	std::istringstream ss(argv[i]);
	if (!(ss >> plottingFine[2])) {
	  std::cerr <<"Invalid number " <<argv[i] <<'\n';
	  exit(1); }
      } }
    else if (arg == "-p4") {
      if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	i++;
	std::istringstream ss(argv[i]);
	if (!(ss >> plottingFine[3])) {
	  std::cerr <<"Invalid number " <<argv[i] <<'\n';
	  exit(1); }
      } }
    else if (arg == "-Bb") {
      if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	i++;
	std::istringstream ss(argv[i]);
	if (!(ss >> bMax)) {
	  std::cerr <<"Invalid number " <<argv[i] <<'\n';
	  exit(1); }
      }
      else
	bMax = TMATH_PI;
    }
    else if (arg == "-k892") {
      k892Star = true;
      ++nKstars;
    }
    else if (arg == "-k800") {
      k800Star = true;
      ++nKstars;
    }
    else if (arg == "-k1410") {
      k1410Star = true;
      ++nKstars;
    }
    else if (arg == "-k1430_0") {
      k1430Star0 = true;
      ++nKstars;
    }
    else if (arg == "-k1430_2") {
      k1430Star2 = true;
      ++nKstars;
    }
    else if (arg == "-k1780") {
      k1780Star = true;
      ++nKstars;
    }
    else if (arg == "-BkgPHSP") {
	bkgPhaseSpace = true;
	bkgFlag = true;
      }
    else if (arg == "-BkgMap") {
	bkgHistMap = true;
	bkgHist = true;
	bkgFlag = true;
      }
    else if (arg == "-BkgMapInt") {
	bkgHistInt = true;
	bkgHist = true;
	bkgFlag = true;
      }
    else if (arg == "-effH") {
	effPdfProd = true;
	effPdfFlat = true;
      }
    else if (arg == "-effHInt") {
	effPdfProd = true;
	effPdfInter = true;
      }
    else if (arg == "-d1") {
      if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	i++;
	std::istringstream ss(argv[i]);
	if (!(ss >> dataPoints[0])) {
	  std::cerr <<"Invalid number " <<argv[i] <<'\n';
	  exit(1); }
      } }
    else if (arg == "-d2") {
      if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	i++;
	std::istringstream ss(argv[i]);
	if (!(ss >> dataPoints[1])) {
	  std::cerr <<"Invalid number " <<argv[i] <<'\n';
	  exit(1); }
      } }
    else if (arg == "-d3") {
      if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	i++;
	std::istringstream ss(argv[i]);
	if (!(ss >> dataPoints[2])) {
	  std::cerr <<"Invalid number " <<argv[i] <<'\n';
	  exit(1); }
      } }
    else if (arg == "-d4") {
      if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	i++;
	std::istringstream ss(argv[i]);
	if (!(ss >> dataPoints[3])) {
	  std::cerr <<"Invalid number " <<argv[i] <<'\n';
	  exit(1); }
      } }
    else if (arg == "-o") {
	outParams = true;
	if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	    i++;
	    outPath = argv[i];
	  } }
    else if (arg == "-local") {
	localRead = true;
      }
    else if (arg == "-b0Var") {
	b0Var = true;

      }
    else if (arg == "-debug") {
	debugging = true;
      }
    else if (arg == "-b0Flag") {
	b0Flag = true;
      }
    else if (arg == "-b0Bar") {
	b0Bar = true;
      }
    else if (arg == "-b0BarPdf") {
	b0BarPdf = true;
      }
      else if (arg == "-hPlots")
    {
      hPlots = true;
        }
    //     else if (arg == "-H")
    // {
    //   hesse = true;
    // }
    else if (arg == "-algos") {
	algos.clear();
	if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	  i++;

	  std::string algosInput= argv[i];
	  std::size_t found = algosInput.find(m);

	  if (found == std::string::npos)
	    {
	      std::cout <<"Minimisation algorithms invalid input : MIGRAD to be called at least once \n";
	      exit(1);
	    }
	  std::cout <<"- Minimisation algorithms sequence : "<<std::endl;

	  for (std::string::size_type l = 0; l < algosInput.length(); ++l)
	    {
	      std::string::value_type algo = algosInput[l];

	      if (algo==m)
		{
		  algos.push_back(migrad);
		  std::cout<<"  - MIGRAD "<<std::endl;
		}
	      else if (algo==h)
		{
		  algos.push_back(hesse);
		  std::cout<<"  - HESSE "<<std::endl;
		}
	      else if (algo==n)
		{
		  algos.push_back(minos);
		  std::cout<<"  - MINOS "<<std::endl;
		}
	      else std:: cout<<"  - \""<<algo<<"\" invalid input, ignored "<<std::endl;
	    }

	} }

    else if (arg == "-fixA") {
	aFix = true;

	if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	    i++;
	    aFixCode = argv[i];
	  } }
    else if (arg == "-fixB") {
	bFix = true;

	if (i + 1 < argc) { // Make sure we aren't at the end of argv!
	    i++;
	    bFixCode = argv[i];
	  } }
    else if (arg == "-fixH") {
	i++;
	printCodes();
      }
  }

  if (b0BarPdf && b0Var) {
    cout <<"Both B0Bar p.d.f. and B0Bar flag as variable selected. \n Incompatible selections, please see instructions below" <<endl;
    printinstruction();
    return 1;
  }
  TString massKPi_name = "massKPi", cosMuMu_name = "cosMuMu", massPsiPi_name = "massPsiPi", phi_name = "phi";
  vector <TString> varNames; // this order must be followed hereafter
  varNames.push_back(massKPi_name); varNames.push_back(massPsiPi_name); varNames.push_back(cosMuMu_name); varNames.push_back(phi_name);
  //TString massKPi_eff_name = "massKPiEff", massPsiPi_eff_name = "massPsiPiEff";
  //TString massKPi_title = "m(K^{-}#pi^{+})",  cosMuMu_title = "cos(#theta_{J/#psi})",  massPsiPi_title = "cos(#theta_{K*})",  phi_title = "#phi";
  TString massKPi_title = "m(K^{-}#pi^{+})",  cosMuMu_title = "cos(#theta_{J/#psi})",  massPsiPi_title = "m(J/#psi#pi^{+})",  phi_title = "#phi";
  vector <TString> varTitles; // same order as varNames
  varTitles.push_back(massKPi_title); varTitles.push_back(massPsiPi_title); varTitles.push_back(cosMuMu_title); varTitles.push_back(phi_title);

  //Defining minimums and maximums
  fptype plotMargin = 0.1;
  fptype massKPi_min = 0.6, massKPi_max = 2.2;
  fptype massPsiPi_min = 3.2, massPsiPi_max = 4.9;

  TString path;
  if (localRead)
    path = "./rootfiles/"; //path = "/lustre/home/adrianodif/RootFiles/Z4430/TMVA/";
  else
    path = "/lustrehome/cristella/work/Z_analysis/exclusive/clean_14ott/original/CMSSW_5_3_22/src/UserCode/MuMuPiKPAT/test/sanjay/selector/TMVA/";

  TString bdtCut = "0p00"; bdtCut  = "-0p03";
  TString fileName = "TMVApp__withBDTCutAt"+bdtCut+"_JPsi_2p0Sig_6p0to9p0SB.root";

  Variable* massKPi = new Variable(massKPi_name.Data(),1.,massKPi_min,massKPi_max); massKPi->numbins = bin[0];
  //Variable* massKPiEff = new Variable(massKPi_eff_name.Data(),1.,0.6,2.2); massKPiEff->numbins = bin[0];
  //Variable* massKPi = new Variable(massKPi_name.Data(),1.,0.6,1.67); massKPi->numbins = bin[0];
  Variable* massPsiPi = new Variable(massPsiPi_name.Data(),TMath::Sqrt(23),massPsiPi_min-plotMargin,massPsiPi_max+plotMargin); massPsiPi->numbins = bin[1];
  //Variable* massPsiPiEff = new Variable(massPsiPi_eff_name.Data(),TMath::Sqrt(23),3.2,4.9); massPsiPiEff->numbins = bin[1];
  // cosine of the psi(nS) helicity angle
  Variable* cosMuMu = new Variable(cosMuMu_name.Data(),0.,-1-plotMargin,1+plotMargin); cosMuMu->numbins = bin[2];
  // cosine of the K* helicity angle
  //Variable* massPsiPi = new Variable(massPsiPi_name.Data(),0.,-1,1); massPsiPi->numbins = bin[2];
  // angle between decay planesd
  Variable* phi = new Variable(phi_name.Data(),0.25,-TMATH_PI-plotMargin,TMATH_PI+plotMargin); phi->numbins = bin[3];
  Variable* b0Beauty;
  if (b0Var)
    b0Beauty = new Variable("B0beauty",0.,-2,+2);

  std::vector<Variable*> obserVariables;
  // same order as varNames
  obserVariables.push_back(massKPi);
  obserVariables.push_back(massPsiPi);
  obserVariables.push_back(cosMuMu);
  obserVariables.push_back(phi);
  Int_t nProjVars = obserVariables.size();

  if (b0Var)
    obserVariables.push_back(b0Beauty);


  std::vector<Variable*> massesVariables;
  massesVariables.push_back(massKPi); massesVariables.push_back(massPsiPi);

  // std::vector<Variable*> obserMasses;
  // obserMasses.push_back(massKPi);
  // obserMasses.push_back(massPsiPi);


  for (Int_t iVar=0; iVar<nProjVars; ++iVar)
    if (bin[iVar] > plottingFine[iVar])
      cout <<"WARNING! Bins for normalisation & integration along " <<varNames[iVar] <<"(" <<bin[iVar] <<") are more than bins for p.d.f. plotting (" <<plottingFine[iVar] <<")\n" <<endl;

  TString plotsName = "";
  TString extension = "eps"; extension = "png";

  if (!nKstars) {
    cout <<"No K* selected (K892,K800,K1410,K1430) please see instructions below" <<endl;
    printinstruction();
    return 1;
  } else {
    cout <<"- Performing Amplitude Analysis fit with\n  " <<nKstars <<" K*(s) on\n  " <<events <<" events, using\n  " <<bin[0] <<" bins for normalisation & integration and\n  " <<plottingFine[0] <<" bins for p.d.f. plotting along m(KPi)" <<endl;
    if (nKstars < 2) {
      datasetName = "Kstar";
      underscores = "_"; }

    if (k892Star) {
      cout <<"  - K*(892)" <<endl;
      datasetName.Append(underscores+"892_1"); plotsName.Append("__892_1");
      kStarNames.push_back("K*_{1}(892)");
    }
    if (k800Star) {
      cout <<"  - K*(800)" <<endl;
      datasetName.Append(underscores+"800_0"); plotsName.Append("__800_0");
      kStarNames.push_back("K*_{0}(800)");
    }
    if (k1410Star) {
      cout <<"  - K*(1410)" <<endl;
      datasetName.Append(underscores+"1410_1"); plotsName.Append("__1410_1");
      kStarNames.push_back("K*_{1}(1410)");
    }
    if (k1430Star0) {
      cout <<"  - K*(1430_0)" <<endl;
      datasetName.Append(underscores+"1430_0"); plotsName.Append("__1430_0");
      kStarNames.push_back("K*_{0}(1430)");
    }
    if (k1430Star2) {
      cout <<"  - K*(1430_2)" <<endl;
      datasetName.Append(underscores+"1430_2"); plotsName.Append("__1430_2");
      kStarNames.push_back("K*_{2}(1430)");}
    if (k1780Star) {
      cout <<"  - K*(1780_3)" <<endl;
      datasetName.Append(underscores+"1780_3"); plotsName.Append("__1780_3");
      kStarNames.push_back("K*_{3}(1780)");}
    if (bkgPhaseSpace) {
      cout <<"  - Three Bodies Phase-space background" <<endl;
      datasetName.Append("__plus__BdToPsiPiK_PHSP"); plotsName.Append("_PHSP");
    }
    if (bkgHist) {
      cout <<"  - Combinatorial background" <<endl;
      datasetName.Append("__withHistoBkg"); plotsName.Append("__withHistoBkg");
    }
    if (effPdfProd ) {
      cout <<"  - With efficiency multiplication" <<endl;
      datasetName.Append("__withEff"); plotsName.Append("__withEff");
    }
    if (b0Bar){
      cout <<"  - With B0Bar dataset" <<endl;
      datasetName.Append("__B0Bar"); plotsName.Append("__B0Bar");
    }
  }

  if (txtfile)
    datasetName = inPath;

  if (datasetName.Contains("InvEff")) // as of now this can only happens if (txtfile)
    plotsName.ReplaceAll("withEff","withInvEff");

  fptype aMin = -aMax;
  fptype bMin = -bMax;


  //CANVAS
  TCanvas* canvas = new TCanvas("Canvas","Canvas",2000,1200);

  Variable* dRadB0  = new Variable("dRadB0",5.0);
  Variable* dRadKs  = new Variable("dRadKs",1.5);
  Variable* psi_nS  = new Variable("psi_nS",1.0);

  //std::vector<Variable* > amplitudeGooVars;
  //std::vector<Variable*> KParams;

  //GooFit
  Variable mBd("mBd", 5.27961) ;
  Variable mKaon("mKaon", 0.493677) ;
  Variable mPion("mPion", 0.13957018) ;

  fptype massMuMu = 0. ;
  if (psi_nS->value == 1.0) massMuMu = 3.096916 ;
  else if (psi_nS->value == 2.0) massMuMu = 3.686109 ;
  else {
    cout <<"psi_nS is neither 1 nor 2, please check it." <<endl;
    return 1; }
  Variable mMuMu("mMuMu", massMuMu);
  const fptype smearing = 0. ;
  Variable smear("smear",smearing) ;

  //TH1F* dataHisto = new TH1F("data","data",BINS,massKPi.lowerlimit,massKPi.upperlimit);
  //TH1F pdfBkgHist ("bkg","bkg",BINS,massKPi.lowerlimit,massKPi.upperlimit);
  // B^{0} -> psi(nS) #pi^{+} K^{-}

  //cout <<"\nBdToMuMuPiK_PHSP.getVal() =\n" <<BdToMuMuPiK_PHSP->getVal() <<endl; return;

  //fptype roll=0.0;
  //fptype func=0.0;

  long int ms; struct timeval tp;

  gettimeofday(&tp,NULL);
  ms = tp.tv_sec * 1000 + tp.tv_usec / 1000;
  TRandom ranGen(ms);

  std::vector<Variable*> Masses, Gammas, Spins, as, bs;

  if (k892Star) {
    cout <<"\nAdding K*(892) ..." <<endl;

    if (!evtGen) {
      Masses.push_back(new Variable("K_892_Mass_0",M892));
      Gammas.push_back(new Variable("K_892_Gamma_0",G892));
      Spins.push_back(new Variable("K_892_Spin_0",1.0));
      as.push_back(new Variable("a_K_892_0",1.0));//,aMin,aMax) );
      bs.push_back(new Variable("b_K_892_0",0.0));//,bMin,bMax) );
      as.push_back(new Variable("a_K_892_p1",0.844,aMin,aMax) );
      bs.push_back(new Variable("b_K_892_p1",3.14,bMin,bMax) );
      as.push_back(new Variable("a_K_892_m1",0.196,aMin,aMax));
      bs.push_back(new Variable("b_K_892_m1",-1.7,bMin,bMax));
    } else {
      Masses.push_back(new Variable("K_892_Mass_0",M892e));
      Gammas.push_back(new Variable("K_892_Gamma_0",G892e));
      Spins.push_back(new Variable("K_892_Spin_0",1.0));
      // EvtGen
      as.push_back(new Variable("a_K_892_0",0.775));
      //bs.push_back(new Variable("b_K_892_0",0.0));
      //as.push_back(new Variable("a_K_892_0",0.775,0.50,0.8));
      bs.push_back(new Variable("b_K_892_0",0.0));
      as.push_back(new Variable("a_K_892_p1",0.159,0.14,0.17) );
      bs.push_back(new Variable("b_K_892_p1",1.563,1.4,1.57) );
      as.push_back(new Variable("a_K_892_m1",0.612,0.50,0.63));
      bs.push_back(new Variable("b_K_892_m1",2.712,1.0,2.73));
    }

  }

  if (k800Star) {
    cout <<"Adding K*(800) ..." <<endl;

    Masses.push_back(new Variable("K_800_Mass_0",M800));
    Gammas.push_back(new Variable("K_800_Gamma_0",G800));
    Spins.push_back(new Variable("K_800_Spin_0",0.0));
    as.push_back(new Variable("a_K_800_0",1.12,aMin,aMax) );
    bs.push_back(new Variable("b_K_800_0",2.3,bMin,bMax) );
  }

  if (k1410Star) {
    cout <<"Adding K*(1410) ..." <<endl;

    Masses.push_back(new Variable("K_1410_Mass_0",M1410));
    Gammas.push_back(new Variable("K_1410_Gamma_0",G1410));
    Spins.push_back(new Variable("K_1410_Spin_0",1.0));
    as.push_back(new Variable("a_K_1410_0",0.119,aMin,aMax) );
    bs.push_back(new Variable("b_K_1410_0",0.81,bMin,bMax) );

    //as.push_back(new Variable("a_K_1410_0",0.844));
    //bs.push_back(new Variable("b_K_1410_0",3.14,bMin,bMax));

    as.push_back(new Variable("a_K_1410_p1",0.123,aMin,aMax) );
    bs.push_back(new Variable("b_K_1410_p1",-1.04,bMin,bMax) );

    as.push_back(new Variable("a_K_1410_m1",0.036,aMin,aMax));
    bs.push_back(new Variable("b_K_1410_m1",0.67,bMin,bMax));
  }

  if (k1430Star0) {
    cout <<"Adding K*(1430_0) ..." <<endl;

    Masses.push_back(new Variable("K_1430_0_Mass_0",M1430_0));
    Gammas.push_back(new Variable("K_1430_0_Gamma_0",G1430_0));
    Spins.push_back(new Variable("K_1430_0_Spin_0",0.0));
    as.push_back(new Variable("a_K_1430_0_0",0.89,aMin,aMax) );
    bs.push_back(new Variable("b_K_1430_0_0",-2.17,bMin,bMax) );
  }

  if (k1430Star2) {
    cout <<"Adding K*(1430_2) ..." <<endl;

    Masses.push_back(new Variable("K_1430_2_Mass_0",M1430_2));
    Gammas.push_back(new Variable("K_1430_2_Gamma_0",G1430_2));
    Spins.push_back(new Variable("K_1430_2_Spin_0",2.0));
    as.push_back(new Variable("a_K_1430_2_0",4.66,aMin,aMax) );
    bs.push_back(new Variable("b_K_1430_2_0",-0.32,bMin,bMax) );

    //as.push_back(new Variable("a_K_1430_2_0",0.844));
    //bs.push_back(new Variable("b_K_1430_2_0",3.14,bMin,bMax));

    as.push_back(new Variable("a_K_1430_2_p1",4.65,aMin,aMax) );
    bs.push_back(new Variable("b_K_1430_2_p1",-3.05,bMin,bMax) );

    as.push_back(new Variable("a_K_1430_2_m1",1.26,aMin,aMax));
    bs.push_back(new Variable("b_K_1430_2_m1",-1.92,bMin,bMax));
  }

  if (k1780Star) {
    cout <<"Adding K*(1780)_3 ..." <<endl;

    Masses.push_back(new Variable("K_1780_3_Mass_0",M1780_3));
    Gammas.push_back(new Variable("K_1780_3_Gamma_0",G1780_3));
    Spins.push_back(new Variable("K_1780_3_Spin_0",3.0));
    as.push_back(new Variable("a_K_1780_3_0",16.8,aMin,aMax) );
    bs.push_back(new Variable("b_K_1780_3_0",-1.43,bMin,bMax) );

    //as.push_back(new Variable("a_K_1780_3_0",0.844));
    //bs.push_back(new Variable("b_K_1780_3_0",3.14,bMin,bMax));

    as.push_back(new Variable("a_K_1780_3_p1",19.1,aMin,aMax) );
    bs.push_back(new Variable("b_K_1780_3_p1",2.03,bMin,bMax) );

    as.push_back(new Variable("a_K_1780_3_m1",10.2,aMin,aMax));
    bs.push_back(new Variable("b_K_1780_3_m1",1.55,bMin,bMax));
  }

  Int_t nHelAmps = as.size();

  if (nHelAmps!=aFixCode.size() && aFix)
    {
      std::cout<<aFixCode.size()<<"-digits code provided for amplitude fix and "<<nHelAmps<<" amplitudes provided. \n Not matching, returning."<<std::endl;
      return -1;
    }
  if (nHelAmps!=bFixCode.size() && bFix)
    {
      std::cout<<bFixCode.size()<<"-digits code provided for phase fix and "<<nHelAmps<<" phase provided. \n Not matching, returning."<<std::endl;
      return -1;
    }

  if (aFix)
    for (Int_t i = 0; i < nHelAmps; i++)
      if (aFixCode.data()[i]=='1') as[i]->fixed = true;


  if (bFix)
    for (Int_t i = 0; i < nHelAmps; i++)
      if (bFixCode.data()[i]=='1') bs[i]->fixed = true;

  fptype ratios[nProjVars];
  for (Int_t iVar=0; iVar<nProjVars; ++iVar)
    ratios[iVar] = (fptype)plottingFine[iVar]/(fptype)dataPoints[iVar];


  //DATASET
  UnbinnedDataSet dataset(obserVariables);
  UnbinnedDataSet dataset_EffCorr(obserVariables);
  std::vector<fptype> effCorrection, bkgAddition;

  std::cout<<"Dataset: "<<std::endl;
  // std::cout<<" - dataset with "<<dataset.getNumBins()<<" bins "<<std::endl;
  //std::cout<<" - efficiencyDatasetMasses with "<<efficiencyDatasetMasses->getNumBins()<<" bins "<<std::endl;

  vector<TH1F*> varHistos, varHistos_effCorr, varHistos_theory;
  TH1F* projBkgHistosInt[nProjVars];

  for (Int_t iVar=0; iVar<nProjVars; ++iVar) {
    TString xTitle = varTitles[iVar];
    if (iVar <= 2) xTitle.Append(" [GeV]");

    Double_t varStep = (obserVariables[iVar]->upperlimit - obserVariables[iVar]->lowerlimit)/((fptype)dataPoints[iVar]);

    TH1F* hist = new TH1F(varNames[iVar]+"_Histo", TString::Format("%s;%s",varNames[iVar].Data(),xTitle.Data()), dataPoints[iVar]+2, obserVariables[iVar]->lowerlimit-varStep, obserVariables[iVar]->upperlimit+varStep);
    hist->SetLineColor(kBlack); hist->SetMarkerColor(kBlack); hist->SetMarkerStyle(kFullCircle);
    varHistos.push_back( hist );

    TH1F* hist_effCorr = (TH1F*)hist->Clone(TString::Format("%s_effCorr",hist->GetName()));
    hist_effCorr->SetTitle(TString::Format("%s effCorr",hist->GetTitle()));
    varHistos_effCorr.push_back( hist_effCorr );

    TH1F* hist_theory = (TH1F*)hist->Clone(TString::Format("%s_theory",hist->GetName()));
    hist_theory->SetMarkerColor(kBlue);hist_theory->SetLineColor(kBlue);
    hist_theory->SetTitle(TString::Format("%s theory",hist->GetTitle()));
    varHistos_theory.push_back( hist_theory );
  }

  //datasetName = "dataGen_B0"; //datasetName = "dataGen_B0bar";
  //datasetName.Append("_B0massConstraint");
  if (datasetName.Contains("dataGen_B0")) plotsDir.Append("/B0");
  else if (datasetName.Contains("dataGen_B0bar")) plotsDir.Append("/B0bar");

  if (evtGen) datasetName.Append("__EvtGen");
  //datasetName.Append("_mPhi");

  TString fullDatasetName = "./datasets/"+datasetName;
  fullDatasetName = "../datasets/"+datasetName;
  if (txtfile || outParams) {
    datasetName = inPath;
    //datasetName.Append(".txt");
    fullDatasetName = datasetName;
  }

  TString end = fullDatasetName; Ssiz_t endPoint = end.Index("__", fullDatasetName.Length()-10); end.Remove(0,endPoint);
  TString theory_datasetName = fullDatasetName; Ssiz_t startPoint = theory_datasetName.Index("__with"); theory_datasetName.Remove(startPoint); theory_datasetName.Append(end);

  if (txtfile) {
    ifstream dataTxt(fullDatasetName.Data());
    Int_t totEvents = 0;
    if ( !(dataTxt.good()) ) {
      std::cout <<"No valid input at : " <<fullDatasetName <<" provided.\nReturning." <<std::endl;
      return 1;
    } else {
      totEvents = std::count(std::istreambuf_iterator<char>(dataTxt), std::istreambuf_iterator<char>(), '\n');
      if (events > totEvents) {
	cout <<"\nWARNING! The number of events requested is " <<events <<" but " <<fullDatasetName <<" contains only " <<totEvents <<" events." <<endl;
	events = totEvents;
      }

      fptype var1, var2, var3, var4, var5;

      Int_t evt=0;

      cout <<"\n- Reading " <<events <<" out of " <<totEvents <<" events from " <<datasetName <<" and filling UnbinnedDataSet and variables histograms" <<endl;
      dataTxt.clear(); dataTxt.seekg (0, ios::beg);

      ifstream theoryTxt(theory_datasetName.Data());
      if ( theoryTxt.good() ) cout <<"\n- Reading also " <<events <<" events from " <<theory_datasetName <<" and filling corresponding variables histograms" <<endl;

      //while( (evt < events)  &&  (dataTxt >> var1 >> var2 >> var3 >> var4 >> var5) ) { // need to add a check for var5 and skip it if not present in the file
      while( (evt < events)  &&  (dataTxt >> var1 >> var2 >> var3 >> var4) ) {
	evt++;
	massKPi->value = var1; massPsiPi->value = var2; cosMuMu->value = var3; phi->value = var4;
	if (b0Var)
	  b0Beauty->value = var5;
	else if (var5 < 0.0  &&  b0Flag)
	  phi->value *= -1.0;

	//std::cout <<massKPi->value <<" - " <<cosMuMu->value <<" - " <<massPsiPi->value <<" - " <<phi->value <<" - " <<std::endl;
	if (Dalitz_contour_host(massKPi->value, massPsiPi->value, kFALSE, (Int_t)psi_nS->value) ) {
	  dataset.addEvent();
	  for (Int_t iVar=0; iVar<nProjVars; ++iVar)
	    varHistos[iVar]->Fill(obserVariables[iVar]->value);
	}

	dataTxt.ignore(std::numeric_limits<std::streamsize>::max(), '\n');


	theoryTxt >> var1 >> var2 >> var3 >> var4;
	massKPi->value = var1; massPsiPi->value = var2; cosMuMu->value = var3; phi->value = var4;
	if (Dalitz_contour_host(massKPi->value, massPsiPi->value, kFALSE, (Int_t)psi_nS->value) ) {
	  for (Int_t iVar=0; iVar<nProjVars; ++iVar)
	    varHistos_theory[iVar]->Fill(obserVariables[iVar]->value);
	}

	theoryTxt.ignore(std::numeric_limits<std::streamsize>::max(), '\n');

      }
    } // if ( (dataTxt.good()) )
    dataTxt.close();
  } // if (txtfile)
  else {
    //TString dataFileName = "./datafiles/Data_JPsi_2p0Sig_6p0to9p0SB.root";
    //TString dataFileName = "./datafiles/TMVApp_withBDTCutAt0p00_JPsi_2p0Sig_6p0to9p0SB.root";
    //TString dataFileName = fileName; dataFileName.ReplaceAll("TMVApp_","TMVApp_data");
    TString dataFileName = path+fileName; dataFileName.ReplaceAll("TMVApp_","TMVApp_data");
    TFile *inputFile = TFile::Open(dataFileName);

    if (!inputFile) {
      cout <<"Warning: unable to open data file \"" <<dataFileName <<"\"" <<endl;
    } else {

      TString dataTreeName = "AA_vars";
      TNtupleD* dataNTuple = (TNtupleD*)inputFile->Get(dataTreeName);

      if (!(dataNTuple)){
      	std::cout<<"Data NTuple named \'"<<dataTreeName<<"\' not found in TFile \'" <<inputFile->GetName() <<"\'.\nReturning."<<std::endl;
      	return -1;
      }

      Double_t obs1,obs2,obs3,obs4;

      dataNTuple->SetBranchAddress("massKPi",&obs1);
      dataNTuple->SetBranchAddress("massMuMuPi",&obs2);
      dataNTuple->SetBranchAddress("cosMuMu",&obs3);
      dataNTuple->SetBranchAddress("phi",&obs4);

      Int_t nEntries = dataNTuple->GetEntries();

      if (events > nEntries) {
      	cout <<"\nWARNING! The number of events requested is " <<events <<" but " <<dataFileName <<" contains only " <<nEntries <<" events." <<endl;
      	events = nEntries;
      }

      cout <<"\n- Reading " <<events <<" out of " <<nEntries <<" events from " <<dataFileName <<" and filling variables histograms" <<endl;
      for (Int_t i=0; i<events; i++) {
	dataNTuple->GetEntry(i);

	//std::cout<<obs1<<" - "<<obs2<<" - "<<obs3<<" - "<<obs4<<std::endl;
	massKPi->value = obs1;
	massPsiPi->value = obs2;
	cosMuMu->value = obs3;
	phi->value = obs4;

	if (Dalitz_contour_host(massKPi->value, massPsiPi->value, kFALSE, (Int_t)psi_nS->value) ) {
	  dataset.addEvent();
	  for (Int_t iVar=0; iVar<nProjVars; ++iVar)
	    varHistos[iVar]->Fill(obserVariables[iVar]->value);
	}
      }

      inputFile->Close();
    }
  } // if (!txtfile)

  //OUTPUT PARAMETERS TXT

  std::ofstream outParamsFile;

  if (outParams) {
    std::string outPutPath = outPath+"outParams_"+datasetName.Data();
    outParamsFile.open(outPutPath.data(),std::ofstream::out);
    if ( !(outParamsFile.good()) ) {
      std::cout <<"No path for output parameters txt : " <<outPutPath <<" provided.\nReturning." <<std::endl;
      return 1;
    }
  }

  ////////////////////////

  if (dataset.getNumEvents() < 1) {
    cout <<"No events added from "  <<fullDatasetName <<"\nReturning." <<endl;
    return 0;
  } else
    std::cout <<"\nAdded " <<dataset.getNumEvents() <<" events within Dalitz border to GooFit dataset" <<std::endl;

  events = dataset.getNumEvents();

  ////////////////////////////////////
  //Efficiencies

  //GooPdf* efficiencyHistMasses, *efficiencyHistAngles;
  GooPdf* effHist, *effHistAng, *effHistMas;
  //GooPdf* effHistPlot;

  BinnedDataSet* effDataset, *effDatasetMasses, *effDatasetAngles;

  ////////////////////////////////////
  //Backgrounds
  GooPdf* bkgHistMasses, *bkgHistAngles;
  GooPdf* bkgHistPdf;
  GooPdf* bkgHistPdfPlot;

  BinnedDataSet* bkgDatasetMasses, *bkgDatasetAngles;
  BinnedDataSet* bkgDataset;

  std::cout<<"\nInitialising pdfs " <<std::endl;
  std::cout<<"\n- Matrix p.d.f. " <<std::endl;
  if (effPdfProd) {

    int holdBinVar[nProjVars];
    fptype lowerL[nProjVars], upperL[nProjVars];

    //int outCounter = 0;

    // path = "./effFiles/";
    //TString effName = "officialMC_noPtEtaCuts_JPsi_Bd2MuMuKPi_2p0Sig_4p0to6p0SB.root";
    TString effName = path + fileName; effName.ReplaceAll("TMVApp_","TMVApp_MC");

    TFile *effFile = TFile::Open(effName);
    if (!effFile) {
      cout <<"ERROR! Unable to open efficiency file \"" <<effName <<"\".\nReturning" <<endl;
      return -1;
    }

    //TString relEffNameMass = "RelEff_psi2SPi_vs_KPi_B0constr";
    TString relEffNameMass = "RelEff_psi2SPi_vs_KPi_B0constr_1B0";
    TString relEffNameAng = "RelEff_planesAngle_vs_cos_psi2S_helicityAngle";
    relEffNameMass.Append("_BDTCutAt"+bdtCut); relEffNameAng.Append("_BDTCutAt"+bdtCut);

    relEffTH2Mass = (TH2F*)effFile->Get(relEffNameMass) ;
    relEffTH2Ang = (TH2F*)effFile->Get(relEffNameAng) ;

    if (!(relEffTH2Mass)) {
      std::cout<<"ERROR! Efficiency TH2 named \'"<<relEffNameMass <<"\' not found in TFile \'" <<effFile->GetName() <<"\'.\nReturning" <<std::endl;
      return -1;
    }
    if (!(relEffTH2Ang)) {
      std::cout<<"ERROR! Efficiency TH2 named \'"<<relEffNameAng <<"\' not found in TFile \'" <<effFile->GetName() <<"\'.\nReturning" <<std::endl;
      return -1;
    }

    relEffTH2[0] = *relEffTH2Mass;
    relEffTH2[1] = *relEffTH2Ang;

    std::cout<<"Masses efficiency TH2 read with bin massKPi ("
    <<relEffTH2Mass->GetXaxis()->GetBinLowEdge(1)<<" ; "
    <<relEffTH2Mass->GetXaxis()->GetBinLowEdge(relEffTH2Mass->GetNbinsX())<<") = "
    <<relEffTH2Mass->GetNbinsX()
    <<" and bin massPsiPi ("
    <<relEffTH2Mass->GetYaxis()->GetBinLowEdge(1)<<" ; "
    <<relEffTH2Mass->GetYaxis()->GetBinLowEdge(relEffTH2Mass->GetNbinsY())<<") = "
    <<relEffTH2Mass->GetNbinsY() <<std::endl;

    std::cout<<"Angles efficiency TH2 read with bin cosMuMu ("
    <<relEffTH2Ang->GetXaxis()->GetBinLowEdge(1)<<" ; "
    <<relEffTH2Ang->GetXaxis()->GetBinLowEdge(relEffTH2Ang->GetNbinsX())
    <<") = " <<relEffTH2Ang->GetNbinsX()
    <<" and bin phi ("
    <<relEffTH2Ang->GetYaxis()->GetBinLowEdge(1)<<" ; "
    <<relEffTH2Ang->GetYaxis()->GetBinLowEdge(relEffTH2Ang->GetNbinsY())
    <<") = " <<relEffTH2Ang->GetNbinsY() <<std::endl;

    for (int y=0; y<nProjVars; y+=2) {
      //std::cout <<"Vars " <<y <<" - " <<y+1 <<"histo index" <<y/2 <<std::endl;

      holdBinVar[y] = obserVariables[y]->numbins;
      obserVariables[y]->numbins = relEffTH2[y/2].GetNbinsX();

      holdBinVar[y+1] = obserVariables[y+1]->numbins;
      obserVariables[y+1]->numbins = relEffTH2[y/2].GetNbinsY();

      lowerL[y] = obserVariables[y]->lowerlimit;
      obserVariables[y]->lowerlimit = relEffTH2[y/2].GetXaxis()->GetBinLowEdge(1);

      lowerL[y+1] = obserVariables[y+1]->lowerlimit;
      obserVariables[y+1]->lowerlimit = relEffTH2[y/2].GetYaxis()->GetBinLowEdge(1);

      upperL[y] = obserVariables[y]->upperlimit;
      obserVariables[y]->upperlimit = relEffTH2[y/2].GetXaxis()->GetBinUpEdge(relEffTH2[y/2].GetNbinsX());

      upperL[y+1] = obserVariables[y+1]->upperlimit;
      obserVariables[y+1]->upperlimit = relEffTH2[y/2].GetYaxis()->GetBinUpEdge(relEffTH2[y/2].GetNbinsX());
    }

    // std::vector< Variable*> massVars;
    // massVars.push_back(obserVariables[iVar1]);
    // massVars.push_back(obserVariables[iVar2]);

    effDatasetMasses = new BinnedDataSet(obserVariables,"efficiency Dataset Masses");
    effDatasetAngles = new BinnedDataSet(obserVariables,"efficiency Dataset Angles");
    effDataset = new BinnedDataSet(obserVariables,"efficiency Dataset");

    // FILLING DATASET WITH HISTOGRAM
    for (int j = 0; j < effDatasetMasses->getNumBins(); ++j) {

      effDatasetMasses->setBinContent(j, relEffTH2Mass->GetBinContent(relEffTH2Mass->FindBin(effDatasetMasses->getBinCenter(massKPi,j),effDatasetMasses->getBinCenter(massPsiPi,j))));
      // if ()
      // {
      //   std::cout<<"Histo content at massKpi : "<<effDatasetMasses->getBinCenter(massKPi,j)<<" and massPsiPi : " <<effDatasetMasses->getBinCenter(massPsiPi,j)<<" is = "<<relEffTH2Mass->GetBinContent(relEffTH2Mass->FindBin(effDatasetMasses->getBinCenter(massKPi,j),effDatasetMasses->getBinCenter(massPsiPi,j)))<<std::endl;
      //   std::cout<<"Binned dataset content : "<<effDatasetMasses->getBinContent(j)<<" at massKpi : "<<effDatasetMasses->getBinCenter(massKPi,j)<<" and massPsiPi : " <<effDatasetMasses->getBinCenter(massPsiPi,j)<<" Bin = "<<j<<std::endl;
      //
      // }
    }

    for (int j = 0; j < effDatasetAngles->getNumBins(); ++j) {

      effDatasetAngles->setBinContent(j,relEffTH2Ang->GetBinContent(relEffTH2Ang->FindBin(effDatasetAngles->getBinCenter(cosMuMu,j),effDatasetAngles->getBinCenter(phi,j))));
      // if ((relEffTH2Ang->GetBinContent(relEffTH2Ang->FindBin(effDatasetAngles->getBinCenter(cosMuMu,j),effDatasetAngles->getBinCenter(phi,j)))!=0.0))
      // {
      //   std::cout<<"Histo content at cosMuMu : "<<effDatasetAngles->getBinCenter(cosMuMu,j)<<" and phi : " <<effDatasetAngles->getBinCenter(phi,j)<<" is = "<<relEffTH2Ang->GetBinContent(relEffTH2Ang->FindBin(effDatasetAngles->getBinCenter(cosMuMu,j),effDatasetAngles->getBinCenter(phi,j)))<<std::endl;
      //   std::cout<<"Binned dataset content : "<<effDatasetAngles->getBinContent(j)<<" at cosMuMu : "<<effDatasetAngles->getBinCenter(cosMuMu,j)<<" and phi : " <<effDatasetAngles->getBinCenter(phi,j)<<" Bin = "<<j<<std::endl;
      // }
    }

    for (int j = 0; j < effDataset->getNumBins(); ++j) {

      for (Int_t iVar=0; iVar<nProjVars; ++iVar)
	obserVariables[iVar]->value = effDataset->getBinCenter(obserVariables[iVar],j);
      if (b0Var)
        b0Beauty->value = 1.0;

      fptype massEff = effDatasetMasses->getBinContent(effDatasetMasses->getBinNumber());
      fptype anglEff = effDatasetAngles->getBinContent(effDatasetAngles->getBinNumber());

      effDataset->setBinContent(j, massEff*anglEff);
      // if (massEff!=0.0 && anglEff!=0.0)
      // {
      //   std::cout<<"MassKPi : "<<massKPi->value<<" - MassPsiPi : "<<massPsiPi->value<<" - Phi : "<<phi->value<<" - CosMuMu : "<<cosMuMu->value<<std::endl;
      //   std::cout<<"Ang efficiency "<<anglEff<<" and massPsiPi : " <<massEff<<" tot eff : "<<anglEff*massEff<<std::endl;
      //   std::cout<<"Histo content = "<<relEffTH2Mass->GetBinContent(relEffTH2Mass->FindBin(effDataset->getBinCenter(massKPi,j),effDatasetMasses->getBinCenter(massPsiPi,j)))<<std::endl;
      //   std::cout<<"Histo content = "<<relEffTH2Ang->GetBinContent(relEffTH2Ang->FindBin(effDataset->getBinCenter(cosMuMu,j),effDatasetMasses->getBinCenter(phi,j)))<<std::endl;
      //
      // }

    }

    for (int i=0; i < events; ++i) {

      dataset.loadEvent(i);
      vector <fptype> varValues;
      for (Int_t iVar=0; iVar<nProjVars; ++iVar) {
	varValues.push_back(obserVariables[iVar]->value);
	obserVariables[iVar]->value = effDataset->getBinCenter(obserVariables[iVar],i) ;
      }
      fptype massEff = effDatasetMasses->getBinContent(effDatasetMasses->getBinNumber());
      fptype anglEff = effDatasetAngles->getBinContent(effDatasetAngles->getBinNumber());

      dataset_EffCorr.addEventVector(varValues, 1/(massEff*anglEff));

      for (Int_t iVar=0; iVar<nProjVars; ++iVar)
	varHistos_effCorr[iVar]->Fill(obserVariables[iVar]->value, 1/(massEff*anglEff));

    }

    if (effPdfFlat) {
      effHistAng = new FlatHistoPdf("EfficienciesPdfAng",effDatasetAngles,obserVariables);
      effHistMas = new FlatHistoPdf("EfficienciesPdfMas",effDatasetMasses,obserVariables);
      effHist = new FlatHistoPdf("EfficienciesPdf",effDataset,obserVariables);
      //effHistPlot = new FlatHistoPdf("EfficienciesPdf",effDataset,obserVariables);
    } else if (effPdfInter)
      {
         effHistAng = new BiDimHistoPdf("EfficienciesPdfAng",effDatasetAngles,obserVariables);
         effHistMas = new BiDimHistoPdf("EfficienciesPdfMas",effDatasetMasses,obserVariables);
	       effHist = new BiDimHistoPdf("EfficienciesPdf",effDataset,obserVariables);
      }
    //efficiencyHistMasses = new BiDimHistoPdf ("EfficiencyPdf",effDatasetMasses,massVars,1);
    // UnbinnedDataSet plottingGridMasses(massVars);
    //
    //
    // for (int i = 0; i < massKPi->numbins; ++i)
    // {
    //     //pdfTestValues.push_back(0.0);
    //     massKPi->value = massKPi->lowerlimit + (massKPi->upperlimit - massKPi->lowerlimit)*(i + 0.5) / massKPi->numbins;
    //     for (int j = 0; j < massPsiPi->numbins; ++j)
    //     {
    //       massPsiPi->value = massPsiPi->lowerlimit + (massPsiPi->upperlimit - massPsiPi->lowerlimit)*(j + 0.5) / massPsiPi->numbins;
    //       plottingGridMasses.addEvent();
    //     }
    // }

    for (int y=0; y<nProjVars;++y){
        obserVariables[y]->lowerlimit = lowerL[y];
        obserVariables[y]->upperlimit = upperL[y];
    }

    for (Int_t iVar=0; iVar<nProjVars; ++iVar)
        obserVariables[iVar]->numbins = plottingFine[iVar];

    UnbinnedDataSet plottingGridDataFirst(obserVariables);

    if (b0Var)
      b0Beauty->value = 1.0;

      for (int k = 0; k < phi->numbins; ++k) {
          phi->value = phi->lowerlimit + (phi->upperlimit - phi->lowerlimit)*(k + 0.5) / phi->numbins;
          //std::cout <<"Phi : " <<k <<std::endl;
          for (int j = 0; j < cosMuMu->numbins; ++j) {
            cosMuMu->value = cosMuMu->lowerlimit + (cosMuMu->upperlimit - cosMuMu->lowerlimit)*(j + 0.5) / cosMuMu->numbins;
            //std::cout <<"CosMu : " <<j <<std::endl;
            for (int a = 0; a < massPsiPi->numbins; ++a) {
              massPsiPi->value = massPsiPi->lowerlimit + (massPsiPi->upperlimit - massPsiPi->lowerlimit)*(a + 0.5) / massPsiPi->numbins;
              //std::cout <<"CosK : " <<a <<std::endl;
              for (int i = 0; i < massKPi->numbins; ++i) {
                //std::vector<std::vector<fptype> > tempValues;
                //UnbinnedDataSet tempData(obserVariables);
                massKPi->value = massKPi->lowerlimit + (massKPi->upperlimit - massKPi->lowerlimit)*(i + 0.5) / massKPi->numbins;
                plottingGridDataFirst.addEvent();
              }
            }
          }
        }

      std::vector<std::vector<fptype> > effPdfValues;

      effHist->setData(&plottingGridDataFirst);
      effHist->getCompProbsAtDataPoints(effPdfValues);

      for (size_t i = 0; i < effPdfValues[0].size(); i++) {
        effCorrection.push_back(effPdfValues[0][i]);
      }

      effFile->Close();

      for (Int_t iVar=0; iVar<nProjVars; ++iVar)
          obserVariables[iVar]->numbins = holdBinVar[iVar];

  } // if (effPdfProd)


  //PDFs
  GooPdf* matrix, *background, *sumPdf, *totalPdf,*prodPdf;

  vector<PdfBase*> pdfComponents;
  vector<Variable*> pdfYield;

  std::string p = "phasespace";

  //Variable* sFrac = new Variable("sFrac",0.5,0.,1.0);
  Variable* sFrac = new Variable("sFrac",0.7);
  //Variable* halfFrac = new Variable("halfFrac",0.25);

  if (b0Var)
    matrix = new MatrixPdf("Kstars_signal", massKPi, cosMuMu, massPsiPi, phi, b0Beauty, Masses,Gammas,Spins,as,bs,psi_nS,dRadB0,dRadKs);
  else if (b0BarPdf)
    matrix = new MatrixPdf("Kstars_signal", Masses, Gammas, Spins, as,bs,psi_nS,dRadB0,dRadKs,massKPi, cosMuMu, massPsiPi, phi);
  else
    matrix = new MatrixPdf("Kstars_signal", massKPi, cosMuMu, massPsiPi, phi,Masses,Gammas,Spins,as,bs,psi_nS,dRadB0,dRadKs);

  std::cout<<"\nInitialising p.d.f.s components"<<std::endl;
  if (bkgPhaseSpace) {
    std::cout<<"\n- Bakground phase-space p.d.f."<<std::endl;
    background = new ThreeBodiesPsiPiK("phasespace",massKPi,cosMuMu,massPsiPi,phi,&mBd,&mPion,&mKaon,&mMuMu);

    if (effPdfProd) {
      std::cout<<"\n- Efficiency map p.d.f."<<std::endl;

      pdfComponents.push_back(matrix);
      pdfComponents.push_back(effHist);

      prodPdf  = new ProdPdf("(Kstars_signal + phaseSpace) * efficiency",pdfComponents);
      totalPdf = new AddPdf("Kstars_signal + PhaseSpace", sFrac, prodPdf,background);

      // pdfComponents.push_back(efficiencyHistMasses);
      // pdfComponents.push_back(efficiencyHistAngles);
      }
    else
    {
      totalPdf     = new AddPdf("Kstars_signal + PhaseSpace", sFrac, matrix,background);
    }

  }
  else {
    if (bkgHist) {
      std::cout<<"\n- Background map p.d.f."<<std::endl;

      int holdBinVar[nProjVars];
      fptype lowerL[nProjVars], upperL[nProjVars];

      // path = "./datafiles/";
      //TString bkgName = "Data_JPsi_2p0Sig_6p0to9p0SB.root";
      TString bkgName = fileName; bkgName.ReplaceAll("TMVApp_","TMVApp_data");
      TFile *bkgFile = TFile::Open(path+bkgName);

      TString bkgNameMass = "psi2SPi_vs_KPi_masses_sbs_BDT";
      TString bkgNameAng = "planesAngle_vs_cos_psi2S_helicityAngle_sbs_BDT";

      bkgTH2Mass = (TH2F*)bkgFile->Get(bkgNameMass) ;
      bkgTH2Ang = (TH2F*)bkgFile->Get(bkgNameAng) ;

      if (!(bkgTH2Mass)) {
        std::cout<<"Efficiency TH2 named \'"<<bkgNameMass<<"\' NOT FOUND in found in TFile \'" <<bkgFile->GetName() <<"\'.\nReturning."<<std::endl;
        return -1;
      }
      if (!(bkgTH2Ang)) {
        std::cout<<"Efficiency TH2 named \'"<<bkgNameAng<<"\' NOT FOUND in found in TFile \'" <<bkgFile->GetName() <<"\'.\nReturning."<<std::endl;
        return -1;
      }

      bkgTH2[0] = *bkgTH2Mass;
      bkgTH2[1] = *bkgTH2Ang;

      bkgTH2Mass->Scale(1/bkgTH2Mass->GetEntries());
      bkgTH2Ang->Scale(1/bkgTH2Ang->GetEntries());


      std::cout<<"Masses Sidebands TH2 read with bin massKPi = " <<bkgTH2Mass->GetNbinsX() <<" and bin massPsiPi = " <<bkgTH2Mass->GetNbinsY() <<std::endl;
      std::cout<<"Angles Sidebands TH2 read with bin cosMuMu = " <<bkgTH2Ang->GetNbinsX() <<" and bin phi = " <<bkgTH2Ang->GetNbinsY() <<std::endl;

      for (int y=0; y<nProjVars; y+=2) {

        // std::cout<<"Vars "<<y<<" - "<<y+1<<"histo index"<<y/2<<std::endl;

        // std::cout<<"Name : "<<obserVariables[y]->name<<" "<<obserVariables[y]->numbins<<" "<<obserVariables[y]->lowerlimit<<" "<<obserVariables[y]->upperlimit<<std::endl;
        // std::cout<<"Name : "<<obserVariables[y+1]->name<<" "<<obserVariables[y+1]->numbins<<" "<<obserVariables[y+1]->lowerlimit<<" "<<obserVariables[y+1]->upperlimit<<std::endl;

        holdBinVar[y] = obserVariables[y]->numbins;
        obserVariables[y]->numbins = bkgTH2[y/2].GetNbinsX();

        holdBinVar[y+1] = obserVariables[y+1]->numbins;
        obserVariables[y+1]->numbins = bkgTH2[y/2].GetNbinsY();

        lowerL[y] = obserVariables[y]->lowerlimit;
        obserVariables[y]->lowerlimit = bkgTH2[y/2].GetXaxis()->GetBinLowEdge(1);

        lowerL[y+1] = obserVariables[y+1]->lowerlimit;
        obserVariables[y+1]->lowerlimit = bkgTH2[y/2].GetYaxis()->GetBinLowEdge(1);

        upperL[y] = obserVariables[y]->upperlimit;
        obserVariables[y]->upperlimit = bkgTH2[y/2].GetXaxis()->GetBinUpEdge(bkgTH2[y/2].GetNbinsX());

        upperL[y+1] = obserVariables[y+1]->upperlimit;
        obserVariables[y+1]->upperlimit = bkgTH2[y/2].GetYaxis()->GetBinUpEdge(bkgTH2[y/2].GetNbinsY());

        // std::cout<<"Name : "<<obserVariables[y]->name<<" "<<obserVariables[y]->numbins<<" "<<obserVariables[y]->lowerlimit<<" "<<obserVariables[y]->upperlimit<<std::endl;
        // std::cout<<"Name : "<<obserVariables[y+1]->name<<" "<<obserVariables[y+1]->numbins<<" "<<obserVariables[y+1]->lowerlimit<<" "<<obserVariables[y+1]->upperlimit<<std::endl;
      }

      bkgDatasetMasses = new BinnedDataSet(obserVariables,"bkg Dataset Masses");
      bkgDatasetAngles = new BinnedDataSet(obserVariables,"bkg Dataset Angles");
      bkgDataset = new BinnedDataSet(obserVariables,"bkg Dataset");

      //INITIALIZE TO ZERO
      for (int j = 0; j < bkgDatasetMasses->getNumBins(); ++j)
        bkgDatasetMasses->setBinContent(j,0.0);
      for (int j = 0; j < bkgDatasetAngles->getNumBins(); ++j)
        bkgDatasetAngles->setBinContent(j,0.0);
      for (int j = 0; j < bkgDataset->getNumBins(); ++j)
        bkgDataset->setBinContent(j,0.0);


      // FILLING DATASET WITH HISTOGRAM
      for (int j = 0; j < bkgDatasetMasses->getNumBins(); ++j) {

        bkgDatasetMasses->setBinContent(j, bkgTH2Mass->GetBinContent(bkgTH2Mass->FindBin(bkgDatasetMasses->getBinCenter(massKPi,j),bkgDatasetMasses->getBinCenter(massPsiPi,j))));
        //if ((bkgTH2Mass->GetBinContent(bkgTH2Mass->FindBin(bkgDatasetMasses->getBinCenter(massKPi,j),bkgDatasetMasses->getBinCenter(massPsiPi,j)))!=0.)) {
        //std::cout<<"Histo content at massKpi : "<<bkgDatasetMasses->getBinCenter(massKPi,j)<<" and massPsiPi : " <<bkgDatasetMasses->getBinCenter(massPsiPi,j)<<" is = "<<bkgTH2Mass->GetBinContent(bkgTH2Mass->FindBin(bkgDatasetMasses->getBinCenter(massKPi,j),bkgDatasetMasses->getBinCenter(massPsiPi,j)))<<std::endl;
        //std::cout<<"Binned dataset content : "<<bkgDatasetMasses->getBinContent(j)<<" at massKpi : "<<bkgDatasetMasses->getBinCenter(massKPi,j)<<" and massPsiPi : " <<bkgDatasetMasses->getBinCenter(massPsiPi,j)<<" Bin = "<<j<<std::endl;
        //}
      }

      for (int j = 0; j < bkgDatasetAngles->getNumBins(); ++j) {

        bkgDatasetAngles->setBinContent(j, bkgTH2Ang->GetBinContent(bkgTH2Ang->FindBin(bkgDatasetAngles->getBinCenter(cosMuMu,j),bkgDatasetAngles->getBinCenter(phi,j))));
	//if ((bkgTH2Ang->GetBinContent(bkgTH2Ang->FindBin(bkgDatasetAngles->getBinCenter(cosMuMu,j),bkgDatasetAngles->getBinCenter(phi,j))))!=0.) {
	//std::cout<<"Histo content at phi : "<<bkgDatasetAngles->getBinCenter(phi,j)<<" and cosMuMu : " <<bkgDatasetAngles->getBinCenter(cosMuMu,j)<<" is = "<<bkgTH2Ang->GetBinContent(bkgTH2Ang->FindBin(bkgDatasetAngles->getBinCenter(phi,j),bkgDatasetAngles->getBinCenter(cosMuMu,j)))<<std::endl;
	//std::cout<<"Binned dataset content : "<<bkgDatasetAngles->getBinContent(j)<<" at phi : "<<bkgDatasetAngles->getBinCenter(phi,j)<<" and cosMuMu : " <<bkgDatasetAngles->getBinCenter(cosMuMu,j)<<" Bin = "<<j<<std::endl;
	//}
      }

      for (int j = 0; j < bkgDataset->getNumBins(); ++j) {
        fptype anglesContent = bkgTH2Ang->GetBinContent(bkgTH2Ang->FindBin(bkgDataset->getBinCenter(cosMuMu,j), bkgDataset->getBinCenter(phi,j)));
        fptype massesContent = bkgTH2Mass->GetBinContent(bkgTH2Mass->FindBin(bkgDataset->getBinCenter(massKPi,j), bkgDataset->getBinCenter(massPsiPi,j)));
        //if (anglesContent!=0.0 && massesContent !=0.0) std::cout<<"Both not ZERO "<<anglesContent<<" - "<<massesContent<<std::endl;
        //if (anglesContent!=0.0) std::cout<<"Angles not ZERO "<<anglesContent<<" - "<<massesContent<<std::endl;
        //if (massesContent!=0.0) std::cout<<"Masses not ZERO "<<anglesContent<<" - "<<massesContent<<std::endl;

        bkgDataset->setBinContent(j, anglesContent * massesContent);

      }

      for (int j = 0; j < bkgDataset->getNumBins(); ++j)
        if (bkgDataset->getBinContent(j) > 1)
          std::cout<<"Binned dataset content : "<<bkgDataset->getBinContent(j)<<std::endl;

      /*
	int noOfEntries = bkgTH2Mass->GetEntries() + bkgTH2Ang->GetEntries();
	std::cout<<"Dataset events : " <<bkgDataset->getNumEvents()<<" histograms : " <<noOfEntries <<std::endl;
	std::cout<<"Mass histo : " <<bkgTH2Mass->GetEntries()<<" Angles histo : " <<bkgTH2Ang->GetEntries() <<std::endl;
      */
      if (bkgHistMap) {
        bkgHistMasses = new FlatHistoPdf("bkgHistMasses",bkgDatasetMasses,obserVariables);
        bkgHistAngles = new FlatHistoPdf("bkgHistAngles",bkgDatasetAngles,obserVariables);
        bkgHistPdf    = new FlatHistoPdf("bkgHistPdf",bkgDataset,obserVariables);
      }
      else if (bkgHistInt) {
        bkgHistMasses = new BiDimHistoPdf("bkgHistMasses",bkgDatasetMasses,obserVariables);
        bkgHistAngles = new BiDimHistoPdf("bkgHistAngles",bkgDatasetAngles,obserVariables);
        bkgHistPdf    = new BiDimHistoPdf("bkgHistPdf",bkgDataset,obserVariables);
      }

	  bkgHistos[0] = bkgTH2Mass->ProjectionX(); bkgHistos[1] = bkgTH2Mass->ProjectionY();
	  bkgHistos[2] = bkgTH2Ang->ProjectionX(); bkgHistos[3] = bkgTH2Ang->ProjectionY();

      if (bkgHistInt)
        bkgHistPdfPlot = new BiDimHistoPdf("bkgHistPdf",bkgDataset,obserVariables);
      else if (bkgHistMap)
        bkgHistPdfPlot = new FlatHistoPdf("bkgHistPdf",bkgDataset,obserVariables);

      bkgHistPdfPlot->setData(bkgDataset);

      //bkgHistAngles->getValue();
      TH2F* bkgHistosInt[2];
      TH1F* projMassKPiHistoBkgInt, *projMassPsiPiHistoBkgInt, *projCosMuMuHistoBkgInt, *projPhiHistoBkgInt;

      bkgHistosInt[0] = new TH2F("bkgHistosInt[0]","bkgHistosInt[0]", massKPi->numbins, massKPi->lowerlimit, massKPi->upperlimit,massPsiPi->numbins, massPsiPi->lowerlimit, massPsiPi->upperlimit);
      bkgHistosInt[1] = new TH2F("bkgHistosInt[1]","bkgHistosInt[1]", cosMuMu->numbins, cosMuMu->lowerlimit, cosMuMu->upperlimit,phi->numbins, phi->lowerlimit, phi->upperlimit);

      fptype massKPiStep = (massKPi->upperlimit-massKPi->lowerlimit)/(fptype)massKPi->numbins;
      fptype massPsiPiStep = (massPsiPi->upperlimit-massPsiPi->lowerlimit)/(fptype)massPsiPi->numbins;
      fptype phiStep = (phi->upperlimit-phi->lowerlimit)/(fptype)phi->numbins;
      fptype cosMuMuStep = (cosMuMu->upperlimit-cosMuMu->lowerlimit)/(fptype)cosMuMu->numbins;

      std::cout<<"-Producing sidebands background plots"<<std::endl;

      fptype interpolationSum = 0.0;
      std::vector< std::vector <fptype> > pdfIntValues;
      bkgHistPdfPlot->getCompProbsAtDataPoints(pdfIntValues);

      //PLOTTING MASSES
      //   ==================================================
      //   array ind   coordinates where the pdf is evaluated
      //   ==================================================
      //   0                phi0 cosMu0 cosk0 mkp0
      //   1                phi0 cosMu0 cosk0 mkp1
      //   2                phi0 cosMu0 cosk0 mkp2
      //   3                phi0 cosMu0 cosk0 mkp3
      //   4(b1)            phi0 cosMu0 cosk1 mkp0
      //   5                phi0 cosMu0 cosk1 mkp1
      //   . . .
      //   19               phi0 cosMu0 cosk4 mkp3
      //   20(b1*b2)        phi0 cosMu1 cosk0 mkp0
      //   . . .
      //   59               phi0 cosMu2 cosk4 mkp3
      //   60(b1*b2*b3)     phi1 cosMu0 cosk0 mkp0
      //   . . .            phi0 cosMu0 cosk0 mkp3
      //   179              phi2 cosMu2 cosk4 mkp3

      //MASSES PLOT
      for (int j = 0; j < massKPi->numbins; ++j)
        for (int i = 0; i < massPsiPi->numbins; ++i)
          {
            fptype xval   = massKPi->lowerlimit + j*massKPiStep +0.5*massKPiStep;
            fptype yval   = massPsiPi->lowerlimit + i*massPsiPiStep +0.5*massPsiPiStep;

            fptype zval = 0.0;

            for (int k = 0; k < phi->numbins * cosMuMu->numbins; ++k)
              zval += pdfIntValues[0][j+i*massKPi->numbins+k*massKPi->numbins * massPsiPi->numbins];

            interpolationSum += zval;
            bkgHistosInt[0]->SetBinContent(bkgHistosInt[0]->FindBin(xval,yval),zval);
          }


      interpolationSum = .0;
      //PLOTTING ANGLES
      for (int j = 0; j < cosMuMu->numbins; ++j)
        for (int i = 0; i < phi->numbins; ++i)
          {

            fptype xval   = cosMuMu->lowerlimit + j*cosMuMuStep + 0.5*cosMuMuStep;
            fptype yval   = phi->lowerlimit + i*phiStep + 0.5*phiStep;

            fptype zval = 0.0;

            for (int k = 0; k < massKPi->numbins * massPsiPi->numbins; ++k)
              zval += pdfIntValues[0][j * massKPi->numbins * massPsiPi->numbins+ i * massKPi->numbins * massPsiPi->numbins * cosMuMu->numbins + k ];

            interpolationSum += zval;
            bkgHistosInt[1]->SetBinContent(bkgHistosInt[1]->FindBin(xval,yval),zval);

          }

      TCanvas* canvasM = new TCanvas("mcanvas","mcanvas",2000,1200);
      canvasM->cd();

      bkgHistosInt[0]->Scale(1.0/interpolationSum);
      bkgHistosInt[0]->Scale(bkgTH2Mass->GetEntries());

      bkgHistosInt[1]->Scale(1.0/interpolationSum);
      bkgHistosInt[1]->Scale(bkgTH2Ang->GetEntries());

      bkgHistosInt[0]->Draw("LEGO");
      canvasM->SaveAs("./plots/massesBkgInterpolation.png");
      canvasM->Clear();
      std::cout<<"-Producing sidebands background plots"<<std::endl;

      bkgTH2Mass->Draw("LEGO");
      canvasM->SaveAs("./plots/massesBkgHistogram.png");
      canvasM->Clear();
      std::cout<<"-Producing sidebands background plots"<<std::endl;

      bkgHistosInt[0]->Draw("SURF3");
      bkgTH2Mass->Draw("same");
      canvasM->SaveAs("./plots/massesBkgHistogramInterpolation.png");
      canvasM->Clear();
      std::cout<<"-Producing sidebands background plots"<<std::endl;

      for (Int_t y=0; y<nProjVars; y+=2) {

        //std::cout <<"Vars " <<y <<" - " <<y+1 <<"histo index" <<y/2 <<std::endl;
        projBkgHistosInt[y] = (TH1F*)bkgHistosInt[y/2]->ProjectionX();
        projBkgHistosInt[y]->Scale(1.0/projBkgHistosInt[y]->Integral());
        projBkgHistosInt[y]->Scale(bkgHistos[y]->GetEntries());

        projBkgHistosInt[y]->Draw("L");
        bkgHistos[y]->Draw("same");
        canvasM->SaveAs("./plots/massesBkgMKPiProjection.png");
        canvasM->Clear();

        projBkgHistosInt[y+1] = (TH1F*)bkgHistosInt[y/2]->ProjectionY();
        projBkgHistosInt[y+1]->Scale(1.0/projBkgHistosInt[y+1]->Integral());
        projBkgHistosInt[y+1]->Scale(bkgHistos[y+1]->GetEntries());

        projBkgHistosInt[y+1]->Draw("L");
        bkgHistos[y+1]->Draw("same");
        canvasM->SaveAs("./plots/massesBkgMPsiPiProjection.png");
        canvasM->Clear();
      }

      for (Int_t iVar=0; iVar<nProjVars; ++iVar)
      {
        projBkgHistosInt[iVar]->SetMarkerStyle(kFullSquare);
        projBkgHistosInt[iVar]->SetMarkerColor(kBlue);

      }


      canvas->cd();


      for (int y=0; y<nProjVars;++y){
          obserVariables[y]->lowerlimit = lowerL[y];
          obserVariables[y]->upperlimit = upperL[y];
      }

      for (Int_t iVar=0; iVar<nProjVars; ++iVar)
          obserVariables[iVar]->numbins = plottingFine[iVar];

      UnbinnedDataSet plottingGridDataSecond(obserVariables);

      if (b0Var)
        b0Beauty->value = 1.0;

        for (int k = 0; k < phi->numbins; ++k) {
            phi->value = phi->lowerlimit + (phi->upperlimit - phi->lowerlimit)*(k + 0.5) / phi->numbins;
            //std::cout <<"Phi : " <<k <<std::endl;
            for (int j = 0; j < cosMuMu->numbins; ++j) {
              cosMuMu->value = cosMuMu->lowerlimit + (cosMuMu->upperlimit - cosMuMu->lowerlimit)*(j + 0.5) / cosMuMu->numbins;
              //std::cout <<"CosMu : " <<j <<std::endl;
              for (int a = 0; a < massPsiPi->numbins; ++a) {
                massPsiPi->value = massPsiPi->lowerlimit + (massPsiPi->upperlimit - massPsiPi->lowerlimit)*(a + 0.5) / massPsiPi->numbins;
                //std::cout <<"CosK : " <<a <<std::endl;
                for (int i = 0; i < massKPi->numbins; ++i) {
                  //std::vector<std::vector<fptype> > tempValues;
                  //UnbinnedDataSet tempData(obserVariables);
                  massKPi->value = massKPi->lowerlimit + (massKPi->upperlimit - massKPi->lowerlimit)*(i + 0.5) / massKPi->numbins;
                  plottingGridDataSecond.addEvent();
                }
              }
            }
          }

        std::vector<std::vector<fptype> > bkgPdfValues;
        fptype bkgSumPdf = 0.0;

        bkgHistPdf->setData(&plottingGridDataSecond);
        bkgHistPdf->getCompProbsAtDataPoints(bkgPdfValues);

        for (size_t i = 0; i < bkgPdfValues[0].size(); i++) {
          bkgAddition.push_back(bkgPdfValues[0][i]);
        }

        for (int k = 0; k < bkgAddition.size(); k++) {
          //std::cout <<mkpTotalProjection[k]*events/sum<<std::endl;
          bkgSumPdf += bkgAddition[k];
        }

        for (int k = 0; k < bkgAddition.size(); k++) {
          //std::cout <<mkpTotalProjection[k]*events/sum<<std::endl;
          bkgAddition[k] /= bkgSumPdf;
        }

        // bkgFile->Close();

      for (int y=0; y<nProjVars; ++y)
        obserVariables[y]->numbins = holdBinVar[y];


      background = bkgHistPdf;
      //sumPdf = new AddPdf("Kstars_signal + PhaseSpace",weights,pdfComponents);

      pdfComponents.clear();

      if (effPdfProd) {
        std::cout<<"\n- Efficiency p.d.f. "<<std::endl;
        // totalPdf = new ProdPdf("Kstars_signal * efficiency",pdfComponents);
        pdfComponents.push_back(matrix);
        pdfComponents.push_back(effHist);
        prodPdf = new ProdPdf("(Kstars_signal + combinatorial) * efficiency",pdfComponents);
        //pdfComponents.push_back(efficiencyHistMasses);
        //pdfComponents.push_back(efficiencyHistAngles);

        totalPdf  = new AddPdf("Kstars_signal + combinatorial", sFrac, prodPdf, background);
      }
      else
        totalPdf  = new AddPdf("Kstars_signal + combinatorial", sFrac, matrix, background);

      // bkgFile->Close();
    } // if (bkgHist)
    else {
      if (effPdfProd) {
	      pdfComponents.push_back(matrix);
        pdfComponents.push_back(effHist);
	      //pdfComponents.push_back(efficiencyHistMasses);
	      //pdfComponents.push_back(efficiencyHistAngles);
	      totalPdf = new ProdPdf("Kstars_signal * efficiency",pdfComponents);
	      //totalPdf = matrix;
      }
      else
	     totalPdf = matrix;
    }
  } // if (bkgPhaseSpace) else {

  pdfComponents.clear();
  pdfYield.clear();

  totalPdf->setData(&dataset);
  //total->setData(&dataset);

  cout <<"\n- Fitting ..." <<endl;
  //FitManager fitter(total);
  // FitManager* fitter = 0;
  // if (!hesse)
  //   fitter = new FitManager(totalPdf);
  // else
  //   fitter = new FitManager(totalPdf,hesse);

  FitManager* fitter = new FitManager(totalPdf);
  totalPdf->setFitControl(new UnbinnedNllFit());


  gettimeofday(&startTime, NULL);
  startC = times(&startProc);
  //
  fitter->fitOrdered(algos);
  //fitter->fit();
  fitter->getMinuitValues();

  int aCounter = 0;

  if (outParams) {
    for (size_t i = 0; i < Masses.size(); ++i) {
      //std::cout<<as.size()<<" "<<aCounter<<" "<<i<<std::endl;
      outParamsFile <<Masses[i]->name <<" " <<as[aCounter]->value <<" " <<bs[aCounter]->value <<std::endl;
      if (Spins[i] > 0) {
	outParamsFile <<Masses[i]->name <<" "<<as[aCounter+1]->value <<" " <<bs[aCounter+1]->value <<std::endl;
	outParamsFile <<Masses[i]->name <<" " <<as[aCounter+2]->value <<" "<<bs[aCounter+2]->value <<std::endl;

	aCounter += 2;
      }
      ++aCounter;
    }
    outParamsFile <<sFrac->value <<std::endl;
  }

  std::vector<fptype> originalAs, originalBs;

  for (int i = 0; i < nHelAmps; i++) {
    originalAs.push_back(as[i]->value);
    originalBs.push_back(bs[i]->value);
  }

  //
  stopC = times(&stopProc);
  gettimeofday(&stopTime, NULL);
  fptype fitClocks = (stopC - startC)*10000.;

  // Bring phases within [-TMath::Pi,+TMath::Pi]
  fptype period = 2*TMATH_PI;
  for (int i = 0; i < nHelAmps; i++) {
    while (fabs(bs[i]->value) > TMATH_PI)
      bs[i]->value += bs[i]->value > 0 ? -period : +period ;
  }

  totalPdf->clearCurrentFit();

  GooPdf* matrixTotPlot, *bkgHistPlot;

  if (b0Var)
    matrixTotPlot = new MatrixPdf("Signal Pdf Plot", massKPi, cosMuMu, massPsiPi, phi, b0Beauty, Masses,Gammas,Spins,as,bs,psi_nS,dRadB0,dRadKs);
  else if (b0BarPdf)
    matrixTotPlot = new MatrixPdf("Signal Pdf Plot", Masses, Gammas, Spins, as,bs,psi_nS,dRadB0,dRadKs,massKPi, cosMuMu, massPsiPi, phi);
  else
    matrixTotPlot = new MatrixPdf("Signal Pdf Plot", massKPi, cosMuMu, massPsiPi, phi,Masses,Gammas,Spins,as,bs,psi_nS,dRadB0,dRadKs);

  gettimeofday(&startTime, NULL);
  startC = times(&startProc);
  //
  UnbinnedDataSet plottingGridData(obserVariables);

  std::vector<UnbinnedDataSet> compData;
  std::vector<std::vector<fptype> > pdfTotalValues, pdfTotalSigValues, pdfTotalBkgValues;
  std::vector<std::vector<fptype> > pdfCompValues;

  for (int id = 0; id < nKstars; ++id)
    compData.push_back( UnbinnedDataSet(obserVariables) );

  std::vector<fptype> fractions;

  std::vector<fptype> compEvents;

  std::vector<std::vector<fptype> > totalProj(4), totalSigProj(4), totalBkgProj(4);

  if(!hPlots)
    for (Int_t iVar=0; iVar<nProjVars; ++iVar)
      obserVariables[iVar]->numbins = plottingFine[iVar];
  else
    for (Int_t iVar=0; iVar<nProjVars; ++iVar)
      obserVariables[iVar]->numbins = dataPoints[iVar];


  for (Int_t iVar=0; iVar<nProjVars; ++iVar)
    obserVariables[iVar]->numbins = plottingFine[iVar];

  TString shortVarNames[] = {"MKPi","MPsiPi","CMM","Phi"}; // same order as varNames
  vector <fptype*> pointsXTot, pointsYTot, pointsYTotSig, pointsYTotBkg;
  // pdf projection histos used to easily normalize the pdf and get the bin center
  vector <TH1F*> projHistos, projSigHistos, projBkgHistos;
  for (Int_t iVar=0; iVar<nProjVars; ++iVar) {
    pointsXTot.push_back(new fptype[obserVariables[iVar]->numbins]);
    pointsYTot.push_back(new fptype[obserVariables[iVar]->numbins]);
    pointsYTotSig.push_back(new fptype[obserVariables[iVar]->numbins]);
    pointsYTotBkg.push_back(new fptype[obserVariables[iVar]->numbins]);

    projHistos.push_back( new TH1F("projHisto_"+shortVarNames[iVar],"projHisto_"+shortVarNames[iVar],obserVariables[iVar]->numbins,obserVariables[iVar]->lowerlimit,obserVariables[iVar]->upperlimit) );
    projSigHistos.push_back( new TH1F("projSigHisto_"+shortVarNames[iVar],"projSigHisto_"+shortVarNames[iVar],obserVariables[iVar]->numbins,obserVariables[iVar]->lowerlimit,obserVariables[iVar]->upperlimit) );
    projBkgHistos.push_back( new TH1F("projBkgHisto_"+shortVarNames[iVar],"projBkgHisto_"+shortVarNames[iVar],obserVariables[iVar]->numbins,obserVariables[iVar]->lowerlimit,obserVariables[iVar]->upperlimit) );

    for (int i = 0; i < obserVariables[iVar]->numbins; ++i) {
      totalProj[iVar].push_back(0.0);
      totalSigProj[iVar].push_back(0.0);
      totalBkgProj[iVar].push_back(0.0);
    }
  }

  fptype sum = 0.0;
  fptype sumSig = 0.0;
  fptype sumBkg = 0.0;

  std::cout <<"\n- Starting plotting cycle" ;
  std::cout <<"\n- Plotting generated dataset" <<std::endl;

  if (b0Var)
    b0Beauty->value = 1.0;

  for (int k = 0; k < phi->numbins; ++k) {
    phi->value = phi->lowerlimit + (phi->upperlimit - phi->lowerlimit)*(k + 0.5) / phi->numbins;
    //std::cout <<"Phi : " <<k <<std::endl;
    for (int j = 0; j < cosMuMu->numbins; ++j) {
      cosMuMu->value = cosMuMu->lowerlimit + (cosMuMu->upperlimit - cosMuMu->lowerlimit)*(j + 0.5) / cosMuMu->numbins;
      //std::cout <<"CosMu : " <<j <<std::endl;
      for (int a = 0; a < massPsiPi->numbins; ++a) {
        massPsiPi->value = massPsiPi->lowerlimit + (massPsiPi->upperlimit - massPsiPi->lowerlimit)*(a + 0.5) / massPsiPi->numbins;
        //std::cout <<"CosK : " <<a <<std::endl;
        for (int i = 0; i < massKPi->numbins; ++i) {
          //std::vector<std::vector<fptype> > tempValues;
          //UnbinnedDataSet tempData(obserVariables);
          massKPi->value = massKPi->lowerlimit + (massKPi->upperlimit - massKPi->lowerlimit)*(i + 0.5) / massKPi->numbins;
          plottingGridData.addEvent();
        }
      }
    }
  }
  //
  stopC = times(&stopProc);
  gettimeofday(&stopTime, NULL);
  fptype dataSetClocks = (stopC - startC)*10000.;

  ////////////////////////////////////////////////////////////////////////////////
  ///// TOTAL PDF PLOT
  ////////////////////////////////////////////////////////////////////////////////

  Double_t plotYMax[nProjVars],plotXMax[nProjVars],plotXMin[nProjVars];

  for (Int_t iVar = 0; iVar < nProjVars; ++iVar)
  {
    plotYMax[iVar] = varHistos[iVar]->GetMaximum();
    plotXMax[iVar] = varHistos[iVar]->GetXaxis()->GetBinLowEdge(1);
    plotXMin[iVar] = varHistos[iVar]->GetXaxis()->GetBinUpEdge(varHistos[iVar]->GetNbinsX());
  }

  Float_t xMax = 0.95, yMax = 0.9;
  Float_t legLeft = 0.6, legWidth = 0.15;
  TLegend *legPlot = new TLegend(legLeft, 0.6, legLeft+legWidth, yMax); // 0.6 will be replaced later
  TPaveText *fitStat = new TPaveText(legPlot->GetX2(), 0.4, xMax, yMax, "NDC");

  std::cout <<"\n- Evaluating the total p.d.f." <<std::endl;
  matrixTotPlot->setData(&plottingGridData);

  gettimeofday(&startTime, NULL);
  startC = times(&startProc);
  //
  matrixTotPlot->getCompProbsAtDataPoints(pdfTotalValues);
  int indexComponents = 0;

  //std::cout <<" Vector size : " <<pdfTotalValues.size() <<std::endl;

  //MULTIPLYING TOTAL PDF PLOT BY EFFICIENCY
  //////////////////////////////////////////////////////////////////////
  //PROJECTING PDF ON THE FOUR VARIABLES (mkpi,phi,cosMuMu,cosK)
  //////////////////////////////////////////////////////////////////////
  //   Pdf evaluation vector (pdfTotalValues) structure :
  //
  //   es.
  //   b1 = 4  mKPi
  //   b2 = 5  massPsiPi
  //   b3 = 3  cosMuMu
  //   b4 = 3  phi
  //   ==================================================
  //   array ind   coordinates where the pdf is evaluated
  //   ==================================================
  //   0                phi0 cosMu0 cosk0 mkp0
  //   1                phi0 cosMu0 cosk0 mkp1
  //   2                phi0 cosMu0 cosk0 mkp2
  //   3                phi0 cosMu0 cosk0 mkp3
  //   4(b1)            phi0 cosMu0 cosk1 mkp0
  //   5                phi0 cosMu0 cosk1 mkp1
  //   . . .
  //   19               phi0 cosMu0 cosk4 mkp3
  //   20(b1*b2)        phi0 cosMu1 cosk0 mkp0
  //   . . .
  //   59               phi0 cosMu2 cosk4 mkp3
  //   60(b1*b2*b3)     phi1 cosMu0 cosk0 mkp0
  //   . . .            phi0 cosMu0 cosk0 mkp3
  //   179              phi2 cosMu2 cosk4 mkp3

  if (effPdfProd)
    for (int k = 0; k < pdfTotalValues[0].size(); k++) {

      if(effPdfProd) pdfTotalValues[0][k] *= effCorrection[k];

      // if (bkgPhaseSpace) {
	    //    pdfTotalValues[1][k] *= effDataCont;
	    //     pdfTotalValues[2][k] *= effDataCont;
      // }

    }




  //std::cout <<" Vector proj : " <<pdfTotalValues[0].size()/massKPi->numbins<<std::endl;
  for (int k = 0; k < pdfTotalValues[0+indexComponents].size(); k++) {
    //std::cout <<mkpTotalProjection[k]*events/sum<<std::endl;
    sum += pdfTotalValues[0][k];
    // if (bkgPhaseSpace) {
    //   sumSig += pdfTotalValues[1][k];
    //   sumBkg += pdfTotalValues[2][k];
    // }
  }
  //
  stopC = times(&stopProc);
  gettimeofday(&stopTime, NULL);
  fptype sumClocks = (stopC - startC)*10000.;

  gettimeofday(&startTime, NULL);
  startC = times(&startProc);
  //
  Float_t sigFrac = sFrac->value;
  Float_t bkgFrac = 1 - sigFrac;
  std::cout <<"\n[ Total Pdf sum : " <<sum<<" ] " <<std::endl;

  for (int k = 0; k<pdfTotalValues[0].size(); ++k) {
    //std::cout <<mkpTotalProjection[k]*events/sum<<std::endl;
    pdfTotalValues[0][k] /= sum;
  }

  if (bkgHist)
    for (int i=0; i<pdfTotalValues[0].size(); i++) {
      fptype signal = pdfTotalValues[0][i];
      fptype backg = bkgAddition[i];
      pdfTotalValues[0][i] = sFrac->value*signal + (1-sFrac->value)*backg;
    }

  for (int k = 0; k<pdfTotalValues[0].size(); ++k) {
    pdfTotalValues[0][k] *= events;
    // if (bkgPhaseSpace) {
    //   pdfTotalValues[1][k] /= sumSig;
    //   pdfTotalValues[1][k] *= (events*sigFrac);
    //
    //   pdfTotalValues[2][k] /= sumBkg;
    //   pdfTotalValues[2][k] *= (events*bkgFrac);
    // }
  }



  //
  stopC = times(&stopProc);
  gettimeofday(&stopTime, NULL);
  //////////////////////////////////////////////////////////////////////
  //Timing
  startC = times(&startProc);
  fptype normClocks = (stopC - startC)*10000.;

  //////////////////////////////////////////////////////////////////////
  //PROJECTING PDF ON THE FOUR VARIABLES (mkpi,phi,cosMuMu,cosK)
  //////////////////////////////////////////////////////////////////////
  //   Pdf evaluation vector (pdfTotalValues) structure :
  //
  //   es.
  //   b1 = 4  mKPi
  //   b2 = 5  massPsiPi
  //   b3 = 3  cosMuMu
  //   b4 = 3  phi
  //   ==================================================
  //   array ind   coordinates where the pdf is evaluated
  //   ==================================================
  //   0                phi0 cosMu0 cosk0 mkp0
  //   1                phi0 cosMu0 cosk0 mkp1
  //   2                phi0 cosMu0 cosk0 mkp2
  //   3                phi0 cosMu0 cosk0 mkp3
  //   4(b1)            phi0 cosMu0 cosk1 mkp0
  //   5                phi0 cosMu0 cosk1 mkp1
  //   . . .
  //   19               phi0 cosMu0 cosk4 mkp3
  //   20(b1*b2)        phi0 cosMu1 cosk0 mkp0
  //   . . .
  //   59               phi0 cosMu2 cosk4 mkp3
  //   60(b1*b2*b3)     phi1 cosMu0 cosk0 mkp0
  //   . . .            phi0 cosMu0 cosk0 mkp3
  //   179              phi2 cosMu2 cosk4 mkp3

  Int_t notVarBins[nProjVars];
  for (Int_t iVar=0; iVar<nProjVars; ++iVar)
    notVarBins[iVar] = pdfTotalValues[0].size() / obserVariables[iVar]->numbins ;

  int notMPKBins = pdfTotalValues[0].size()/massKPi->numbins;
  int notCosMuMuBins = pdfTotalValues[0].size()/cosMuMu->numbins;
  int notmassPsiPiBins = pdfTotalValues[0].size()/massPsiPi->numbins;
  int notPhiBins = pdfTotalValues[0].size()/phi->numbins;

  // this is not easy to replace with a loop
  // m(KPi)
  for (int j = 0; j < massKPi->numbins; ++j) {
    for (int i = 0; i < notMPKBins; ++i) {
      totalProj[0][j] += pdfTotalValues[0+indexComponents][j  +  i * massKPi->numbins];
      if (bkgPhaseSpace) {
        totalSigProj[0][j] += pdfTotalValues[1][j  +  i * massKPi->numbins];
        totalBkgProj[0][j] += pdfTotalValues[2][j  +  i * massKPi->numbins];
      }
    }
  }
  // m(PsiPi)
  for (int j = 0; j < massPsiPi->numbins; ++j) {
    for (int k = 0; k < phi->numbins * cosMuMu->numbins; ++k) {
      for (int i = 0; i < massKPi->numbins; ++i) {
        totalProj[1][j] += pdfTotalValues[0+indexComponents][i  +  k * massKPi->numbins * massPsiPi->numbins  +  j * massKPi->numbins];
        if (bkgPhaseSpace) {
	  totalSigProj[1][j] += pdfTotalValues[1][i  +  k * massKPi->numbins * massPsiPi->numbins  +  j * massKPi->numbins];
	  totalBkgProj[1][j] += pdfTotalValues[2][i  +  k * massKPi->numbins * massPsiPi->numbins  +  j * massKPi->numbins];
	}
      }
    }
  }
  /*
  // cos(MuMu)
  for (int j = 0; j < cosMuMu->numbins; ++j) {
  for (int k = 0; k < phi->numbins*cosMuMu->numbins; ++k) {
  for (int i = 0; i < massKPi->numbins; ++i) {
  cosMuMuTotalProjection[j] += pdfTotalValues[0][i+k*massKPi->numbins*massPsiPi->numbins+j*massKPi->numbins];
  }
  }
  }
  *//*
    // cos(K*)
    for (int j = 0; j < massPsiPi->numbins; ++j) {
    for (int k = 0; k < phi->numbins; ++k) {
    for (int i = 0; i < massKPi->numbins*cosMuMu->numbins; ++i) {
    massPsiPiTotalProjection[j] += pdfTotalValues[0][i+j*massKPi->numbins*massPsiPi->numbins+k*massKPi->numbins*cosMuMu->numbins*massPsiPi->numbins];
    }
    }
    }
    */
  // cos(MuMu)
  for (int j = 0; j < cosMuMu->numbins; ++j) {
    for (int k = 0; k < phi->numbins; ++k) {
      for (int i = 0; i < massKPi->numbins*cosMuMu->numbins; ++i) {
        totalProj[2][j] += pdfTotalValues[0+indexComponents][i  +  j * massKPi->numbins * massPsiPi->numbins  +  k * massKPi->numbins * cosMuMu->numbins * massPsiPi->numbins];
        if (bkgPhaseSpace) {
	  totalSigProj[2][j] += pdfTotalValues[1][i  +  j * massKPi->numbins * massPsiPi->numbins  +  k * massKPi->numbins * cosMuMu->numbins * massPsiPi->numbins];
	  totalBkgProj[2][j] += pdfTotalValues[2][i  +  j * massKPi->numbins * massPsiPi->numbins  +  k * massKPi->numbins * cosMuMu->numbins * massPsiPi->numbins];
	}
      }
    }
  }
  // phi
  for (int j = 0; j < phi->numbins; ++j) {
    for (int k = 0; k < massPsiPi->numbins * massKPi->numbins * cosMuMu->numbins; ++k) {
      totalProj[3][j] += pdfTotalValues[0+indexComponents][k  +  j * massKPi->numbins * cosMuMu->numbins * massPsiPi->numbins];
      if (bkgPhaseSpace) {
	totalSigProj[3][j] += pdfTotalValues[1][k  +  j * massKPi->numbins * cosMuMu->numbins * massPsiPi->numbins];
	totalBkgProj[3][j] += pdfTotalValues[2][k  +  j * massKPi->numbins * cosMuMu->numbins * massPsiPi->numbins];
      }
    }
  }

  stopC = times(&stopProc);
  gettimeofday(&stopTime, NULL);
  fptype projClocks = (stopC - startC)*10000.;

  //////////////////////////////////////////////////////////////////////
  //Filling projection histograms
  for (Int_t iVar=0; iVar<nProjVars; ++iVar) {
    for (int j = 0; j < obserVariables[iVar]->numbins; ++j) {
      projHistos[iVar]->SetBinContent(j+1, totalProj[iVar][j]);
      projSigHistos[iVar]->SetBinContent(j+1, totalSigProj[iVar][j]);
      projBkgHistos[iVar]->SetBinContent(j+1, totalBkgProj[iVar][j]);
      //std::cout <<" Bin " <<j <<" center = " <<projHistos[iVar]->GetBinCenter(j+1) <<" : " <<totalProj[iVar][j] <<std::endl;
    }
    projHistos[iVar]->Scale(ratios[iVar]);
    projSigHistos[iVar]->Scale(ratios[iVar]);
    projBkgHistos[iVar]->Scale(ratios[iVar]);

    projSigHistos[iVar]->SetMarkerColor(kRed);
    projSigHistos[iVar]->SetLineColor(kRed);
    projSigHistos[iVar]->SetMarkerStyle(kFullSquare);

    projBkgHistos[iVar]->SetMarkerColor(9);
    projBkgHistos[iVar]->SetLineColor(9);
    projBkgHistos[iVar]->SetMarkerStyle(kFullSquare);

    plotYMax[iVar] = TMath::Max(projHistos[iVar]->GetMaximum(),plotYMax[iVar]);
    plotXMax[iVar] = TMath::Max(projHistos[iVar]->GetXaxis()->GetBinUpEdge(projHistos[iVar]->GetNbinsX()),plotYMax[iVar]);
    plotXMin[iVar] = -TMath::Max(-projHistos[iVar]->GetXaxis()->GetBinLowEdge(1),-plotYMax[iVar]);

    // Filling projection histograms and TGraphs
    for (int j=0; j < obserVariables[iVar]->numbins; ++j) {
      pointsXTot[iVar][j] = projHistos[iVar]->GetBinCenter(j+1);
      pointsYTot[iVar][j] = projHistos[iVar]->GetBinContent(j+1);
      //std::cout <<" Bin " <<j <<" center = " <<projHistos[iVar]->GetBinCenter(j+1) <<" : " <<totalProj[iVar][j] <<std::endl;
    }
  }


  //////////////////////////////////////////////////////////////////////
  //Setting Graphs & MultiGraphs
  vector <TMultiGraph*> multiGraphs;
  vector <TGraph> signalTotalPlot, signalTotalSigPlot, signalTotalBkgPlot;
  for (Int_t iVar=0; iVar<nProjVars; ++iVar) {
    multiGraphs.push_back( new TMultiGraph(varNames[iVar]+"_MultiGraph", TString::Format("%s;%s",varHistos[iVar]->GetTitle(),varHistos[iVar]->GetXaxis()->GetTitle())) );

    TGraph temp = TGraph(obserVariables[iVar]->numbins, pointsXTot[iVar], pointsYTot[iVar]);
    temp.SetLineColor(kRed); temp.SetLineWidth(2);
    signalTotalPlot.push_back( temp );

    TGraph tempSig = TGraph(obserVariables[iVar]->numbins, pointsXTot[iVar], pointsYTotSig[iVar]);
    tempSig.SetLineColor(kRed); tempSig.SetLineWidth(2); tempSig.SetLineStyle(kDashDotted);
    signalTotalSigPlot.push_back( tempSig );

    TGraph tempBkg = TGraph(obserVariables[iVar]->numbins, pointsXTot[iVar], pointsYTotBkg[iVar]);
    tempBkg.SetLineColor(kRed); tempBkg.SetLineWidth(2); tempBkg.SetLineStyle(kDashed);
    signalTotalBkgPlot.push_back( tempBkg );
  }

  //fptype totalIntegral = totalPdf->normalise();
  fptype totalSigIntegral = matrix->normalise();
  //fptype totalComponent = 0.;
  fptype compsIntegral = 0.0;
  std::cout <<"\nTotal Normalisation Factor = " <<totalSigIntegral <<std::endl;

  Int_t nStatEntries = 0;
  Int_t amplitudeCounter = 0;
  Int_t KstarColor[nKstars]; Int_t startingCol = 3, noColor = 5;
  Int_t KstarMarker[nKstars]; Int_t startingMar = 22;
  for (size_t u=0; u<nKstars; ++u) {
    fitStat->AddText(TString::Format("\n------------------  %s  ------------------", kStarNames[u].c_str()));
    KstarColor[u] = startingCol+u;
    KstarMarker[u] = startingMar+u;
    if (KstarColor[u] >= noColor) KstarColor[u]++;
    ((TText*)fitStat->GetListOfLines()->Last())->SetTextColor(KstarColor[u]);
    addHelAmplStat(fitStat, "0", as[amplitudeCounter], bs[amplitudeCounter]); ++amplitudeCounter;
    nStatEntries +=2 ;

    if (Spins[u]->value > 0.) {
      addHelAmplStat(fitStat, "+1", as[amplitudeCounter], bs[amplitudeCounter]); ++amplitudeCounter;
      addHelAmplStat(fitStat, "-1", as[amplitudeCounter], bs[amplitudeCounter]); ++amplitudeCounter;
      nStatEntries +=2 ;
    }
  }

  fitStat->SetTextAlign(12);
  fitStat->SetShadowColor(0);
  fitStat->SetFillColor(0);

  legPlot->AddEntry(varHistos[0], "Generated data", "lpe");

  if(!bkgHist)
    legPlot->AddEntry(varHistos_theory[0], "Theory data", "lpe");

  if(!hPlots){

    legPlot->AddEntry(&signalTotalPlot[0], "Total fit", "l");

    if (bkgPhaseSpace) {
      legPlot->AddEntry(&signalTotalBkgPlot[0], "Phase space only", "l");
      legPlot->AddEntry(&signalTotalSigPlot[0], "K* signal only", "l");
    }

  }else{

    legPlot->AddEntry(projHistos[0], "Total fit", "lpe");

    if (bkgPhaseSpace) {
      legPlot->AddEntry(projBkgHistos[0], "Phase space only", "lpe");
      legPlot->AddEntry(projSigHistos[0], "K* signal only", "lpe");
    }

  }

  ////////////////////////////////////////////////////////////////////////////////
  ///// COMPONENTS PDF PLOT
  ////////////////////////////////////////////////////////////////////////////////
  std::vector<Variable*> MassesPlot, GammasPlot, SpinsPlot;
  std::vector<Variable*> asPlot, bsPlot;

  std::vector< std::vector<TH1F*> > compHistos(nProjVars);

  Bool_t plotSingleKstars = kTRUE; //plotSingleKstars = kFALSE;

  int lastAmplitude = 0;

  for (int i = 0; i < nKstars; ++i) {
    MassesPlot.push_back(Masses[i]);
    GammasPlot.push_back(Gammas[i]);
    SpinsPlot.push_back(Spins[i]);
  }

  for (int k = 0; k < nKstars; ++k) {
    ////////////////////////////////////////////////////////////////////////////////
    //Initialising projection vectors
    // these have not been vectorised because their fill is not similar
    std::vector<fptype> mkpCompProjection, cosMuMuCompProjection, massPsiPiCompProjection, phiCompProjection;

    for (int i = 0; i < massKPi->numbins; ++i)
      mkpCompProjection.push_back(0.0);

    for (int i = 0; i < cosMuMu->numbins; ++i)
      cosMuMuCompProjection.push_back(0.0);

    for (int i = 0; i < massPsiPi->numbins; ++i)
      massPsiPiCompProjection.push_back(0.0);

    for (int i = 0; i < phi->numbins; ++i)
      phiCompProjection.push_back(0.0);

    // Pushing histogram for each projection
    for (Int_t iVar=0; iVar<nProjVars; ++iVar) {
      sprintf(bufferstring,"comp_%d_plotHisto_%s",k,shortVarNames[iVar].Data());
      compHistos[iVar].push_back(new TH1F(bufferstring,bufferstring,obserVariables[iVar]->numbins,obserVariables[iVar]->lowerlimit,obserVariables[iVar]->upperlimit));
    }

    cout <<"\n- Plotting " <<kStarNames[k] <<" component by setting all other components to zero" <<endl;
    sum = 0.0;

    ////////////////////////////////////////////////////////////////////////////////
    // Setting other components to zero and fixing all useful parameters
    for (int l = 0; l < nHelAmps; ++l) {
      as[l]->fixed = true;
      bs[l]->fixed = true;
      //std::cout<<originalAs[l]<<" - "<<originalBs[l]<<std::endl;
    }

    for (int l = 0; l < nHelAmps; ++l) {
      asPlot.push_back(new Variable("zero_a",0.0));
      bsPlot.push_back(new Variable("zero_b",0.0));
    }

    // std::cout<<" Plotting KStars - Mass : "<<Masses[k]->value<<" Spin : "<<Spins[k]->value<<"Last Amplitude : "<<lastAmplitude<<std::endl;
    //For Spin = 0.0 only one component
    if (Spins[k]->value==0.0) {

      as[lastAmplitude]->fixed;
      bs[lastAmplitude]->fixed;
      // std::cout<<" - Amplitude vector pushing: "<<lastAmplitude<<" index ";
      // asPlot.push_back(as[lastAmplitude]);
      // bsPlot.push_back(bs[lastAmplitude]);
      asPlot[lastAmplitude]->value = originalAs[lastAmplitude];
      bsPlot[lastAmplitude]->value = originalBs[lastAmplitude];

      // for (int j = 0; j < nHelAmps; ++j) {
      //   if (j!=lastAmplitude) {
      //     // std::cout<<" putting zero: "<<j<<" index "<<std::endl;
      // 	  asPlot.push_back(new Variable("zero_a",0.0));
      // 	  bsPlot.push_back(new Variable("zero_b",0.0));
      //   }
      // }
      ++lastAmplitude;
    } else {
      // For Spin != 0 three components
      for (int i = lastAmplitude; i <= lastAmplitude+2; ++i) {
        // std::cout<<" - Amplitude vector pushing: "<<i<<" index ";
        as[i]->fixed;
        bs[i]->fixed;
        // asPlot.push_back(as[i]);
        // bsPlot.push_back(bs[i]);
        asPlot[i]->value = originalAs[i];
        bsPlot[i]->value = originalBs[i];
      }
      //     for (int d = 0; d < nHelAmps; ++d) {
      // if (d!=lastAmplitude && d!=lastAmplitude+1 && d!=lastAmplitude+2) {
      //   // std::cout<<" putting zero: "<<d<<" index "<<std::endl;
      //   asPlot.push_back(new Variable("zero_a",0.0));
      //   bsPlot.push_back(new Variable("zero_b",0.0));
      // }}
      lastAmplitude += 3;
    }

    // std::cout<<" --- "<<k<<std::endl;
    // for (size_t i = 0; i < asPlot.size(); i++) {
    //   std::cout<<" - "<<i+1<<" A : "<<asPlot[i]->value<<" B : "<<bsPlot[i]->value<<std::endl;
    // }

    ////////////////////////////////////////////////////////////////////////////////
    // Normalising, integrating and evaluating the single component pdf

    sprintf(bufferstring,"Kstars_signal_plot_%d",k);
    GooPdf* matrixPlot;

    if (b0Var)
      matrixPlot = new MatrixPdf(bufferstring, massKPi, cosMuMu, massPsiPi, phi, b0Beauty, Masses,Gammas,Spins,asPlot,bsPlot,psi_nS,dRadB0,dRadKs);
    else if (b0BarPdf)
      matrixPlot = new MatrixPdf(bufferstring, Masses, Gammas, Spins, asPlot,bsPlot,psi_nS,dRadB0,dRadKs,massKPi, cosMuMu, massPsiPi, phi);
    else
      matrixPlot = new MatrixPdf(bufferstring, massKPi, cosMuMu, massPsiPi, phi,Masses,Gammas,Spins,asPlot,bsPlot,psi_nS,dRadB0,dRadKs);

    matrixPlot->setData(&plottingGridData);
    matrixPlot->copyParams();

    compsIntegral = matrixPlot->normalise();

    fractions.push_back(compsIntegral/totalSigIntegral);
    //fractions.push_back(compsIntegral);

    cout <<"Component " <<kStarNames[k] <<" normalisation factor : " <<compsIntegral <<" (fraction: " <<std::setprecision(3) <<compsIntegral/totalSigIntegral*100.0 <<"%)" <<endl;

    matrixPlot->getCompProbsAtDataPoints(pdfCompValues);

    /* // not working for the moment
    if (effPdfProd)
      for (int k = 0; k < pdfCompValues[0].size(); k++)
	{
	  for (Int_t i = 0; i < nProjVars; ++i)
	    obserVariables[i]->value = plottingGridData.getValue(obserVariables[i],k);

	  fptype effDataCont = effDataset->getBinContent(effDataset->getBinNumber());
	  pdfCompValues[0][k] *= effDataCont;
	}
    */
    matrixPlot->clearCurrentFit();


    for (int i=0; i<pdfCompValues[0].size(); i++) {
      //std::cout <<" Bin : " <<i <<" pdf : " <<pdfCompValues[0][i] <<std::endl;
      sum += pdfCompValues[0][i];
    }

    for (int i=0; i<pdfCompValues[0].size(); i++) {
      pdfCompValues[0][i] /=sum;
      pdfCompValues[0][i] *= events;
      pdfCompValues[0][i] *= (compsIntegral/totalSigIntegral);
      //compHistos[0][i]->SetBinContent(k,pdfCompValues[0][i]);
    }

    ////////////////////////////////////////////////////////////////////////////////
    //Filling single components projections histos

    //MassKPi
    for (int j = 0; j < massKPi->numbins; ++j) {
      for (int i = 0; i < notMPKBins; ++i) {
	mkpCompProjection[j] += pdfCompValues[0][j+i*massKPi->numbins];
      }
      compHistos[0][k]->SetBinContent(j+1,mkpCompProjection[j]);
    }
    compHistos[0][k]->Scale(ratios[0]);

    //Cos K Star
    for (int j = 0; j < cosMuMu->numbins; ++j) {
      for (int l = 0; l < phi->numbins; ++l) {
	for (int i = 0; i < massKPi->numbins*cosMuMu->numbins; ++i) {
	  cosMuMuCompProjection[j] += pdfCompValues[0][i + j*massKPi->numbins*massPsiPi->numbins + l*massKPi->numbins*cosMuMu->numbins*massPsiPi->numbins];
	}
      }
      compHistos[2][k]->SetBinContent(j+1,cosMuMuCompProjection[j]);
    }
    compHistos[2][k]->Scale(ratios[2]);

    //Cos Mu Mu
    for (int j = 0; j < massPsiPi->numbins; ++j) {
      for (int l = 0; l < phi->numbins*cosMuMu->numbins; ++l) {
	for (int i = 0; i < massKPi->numbins; ++i) {
	  massPsiPiCompProjection[j] += pdfCompValues[0][i + l*massKPi->numbins*massPsiPi->numbins + j*massKPi->numbins];
	}
      }
      compHistos[1][k]->SetBinContent(j+1,massPsiPiCompProjection[j]);
    }
    compHistos[1][k]->Scale(ratios[1]);

    //Phi
    for (int j = 0; j < phi->numbins; ++j) {
      for (int l = 0; l < massPsiPi->numbins * massKPi->numbins * cosMuMu->numbins; ++l) {
	phiCompProjection[j] += pdfCompValues[0][l + j*massKPi->numbins*cosMuMu->numbins*massPsiPi->numbins];
      }
      compHistos[3][k]->SetBinContent(j+1,phiCompProjection[j]);
    }
    compHistos[3][k]->Scale(ratios[3]);

    if (bkgFlag  ||  (nKstars > 1  &&  plotSingleKstars)) {
      // Kstars components points array for each projection
      for (Int_t iVar=0; iVar<nProjVars; ++iVar) {
	fptype pointsXComp[obserVariables[iVar]->numbins], pointsYComp[obserVariables[iVar]->numbins];
	// Filling vectors for components projections graphs
	for (int l=0; l < obserVariables[iVar]->numbins; l++) {
	  pointsXComp[l] = compHistos[iVar][k]->GetBinCenter(l+1);
	  pointsYComp[l] = compHistos[iVar][k]->GetBinContent(l+1);
	}

  compHistos[iVar][k]->SetMarkerColor(KstarColor[k]);
  compHistos[iVar][k]->SetLineColor(KstarColor[k]);
  compHistos[iVar][k]->SetMarkerStyle(KstarMarker[k]);

	// Filling components projections graphs
	TGraph* signalCompPlot = new TGraph(obserVariables[iVar]->numbins, pointsXComp, pointsYComp);
	signalCompPlot->SetLineColor(KstarColor[k]); signalCompPlot->SetLineWidth(3); signalCompPlot->SetLineStyle(kDashed);
	signalCompPlot->GetXaxis()->SetTitle( varHistos[iVar]->GetXaxis()->GetTitle() );
	sprintf(bufferstring,"Events / (%.3f)",(obserVariables[iVar]->upperlimit - obserVariables[iVar]->lowerlimit)/obserVariables[iVar]->numbins);
	signalCompPlot->GetYaxis()->SetTitle(bufferstring);
	//signalCompPlot->Draw("");
	multiGraphs[iVar]->Add(signalCompPlot,"L");

  if (iVar==0) {
	  sprintf(bufferstring,"%s (%.2f %)",kStarNames[k].c_str(), compsIntegral/totalSigIntegral*100.);
    if(!hPlots)
      legPlot->AddEntry(signalCompPlot,bufferstring,"l");
    else
      legPlot->AddEntry(compHistos[iVar][k],bufferstring, "lpe");
	}
      }
    } // if (bkgFlag  ||  (nKstars > 1  &&  plotSingleKstars))

    /*
      massKPiHisto.Draw("");
      signalCompPlot->Draw("sameL");

      sprintf(bufferstring,"plots/plot%d.eps",k);
      canvas->SetLogy(1);
      canvas->SaveAs(bufferstring);
      canvas->Clear();
    */

    asPlot.clear();
    bsPlot.clear();
    pdfCompValues.clear();

  } // for (int k = 0; k < nKstars; ++k)

  legPlot->SetY1( yMax - 0.04*(legPlot->GetNRows()) ) ;
  fitStat->SetY1( yMax - 0.03*nStatEntries ) ;

  //Adding single points to plot better and total plots
  fptype pointsX[2], pointsY[2];
  for (Int_t iVar=0; iVar<nProjVars; ++iVar) {
    pointsX[0] = obserVariables[iVar]->lowerlimit; pointsX[1] = obserVariables[iVar]->upperlimit;
    pointsY[0] = 0.01; pointsY[1] = varHistos[iVar]->GetMaximum();
    TGraph* points = new TGraph(2,pointsX,pointsY);
    if (bkgPhaseSpace) {
      multiGraphs[iVar]->Add(&signalTotalBkgPlot[iVar],"L");
      //multiGraphs[iVar]->Add(&signalTotalSigPlot[iVar],"L");
    }
    multiGraphs[iVar]->Add(&signalTotalPlot[iVar],"L");
    //multiGraphs[iVar]->Add(points,"P");

    if (bkgHist) {
      bkgHistos[iVar]->Scale(events*bkgFrac);
      fptype ratioBkg = (fptype)(bkgHistos[iVar]->GetNbinsX()) / (fptype)dataPoints[iVar];
      bkgHistos[iVar]->Scale( ratioBkg );
    }


    ////////////////////////////////////////////////////////////////////////////////
    // PLOTTING
    canvas->cd();
    canvas->Clear();

    if(!hPlots)
    {
      multiGraphs[iVar]->Draw("AL");
      multiGraphs[iVar]->SetMinimum(0.1);
      multiGraphs[iVar]->SetMaximum(2.2 * plotYMax[iVar]);
      varHistos[iVar]->Draw("Esame"); // if drawn without "same", varHistos[iVar]->SetMinimum(0.1) must be called as well
      if(!bkgHist)
        varHistos_theory[iVar]->Draw("Esame");
    }else
    {
      varHistos[iVar]->SetMinimum(0.1);
      varHistos[iVar]->SetMaximum(2.2 * plotYMax[iVar]);
      varHistos[iVar]->Draw("E");
      varHistos_theory[iVar]->Draw("ESAME");

      projHistos[iVar]->SetMarkerColor(kRed);
      projHistos[iVar]->SetMarkerStyle(kFullCircle);
      projHistos[iVar]->Draw("ESAME");

      if (bkgPhaseSpace)
      {
        projSigHistos[iVar]->Draw("ESAME");
        projBkgHistos[iVar]->Draw("PESAME");

      }
      for (int k = 0; k < nKstars; ++k)
        compHistos[iVar][k]->Draw("PESAME");

      if(bkgHist)
        projBkgHistosInt[iVar]->Draw("PESAME");
      }

    if (bkgHistos[iVar]) bkgHistos[iVar]->Draw("same");
    if (iVar==0) { // it's enough on the m(KPi) plot only
      legPlot->Draw(); fitStat->Draw();
    }


    // first Logy(1) and after Logy(0), viceversa does not work
    canvas->SetLogy(0);
    canvas->SaveAs(TString::Format("%s/%s%s.%s",plotsDir.Data(),varNames[iVar].Data(),plotsName.Data(),extension.Data()));
    canvas->SetLogy(1);
    canvas->SaveAs(TString::Format("%s/%s%s__logy.%s",plotsDir.Data(),varNames[iVar].Data(),plotsName.Data(),extension.Data()));
    canvas->Clear();

  }

  cout <<endl;
  cout <<"~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~" <<endl;
  cout <<"PDF fitting time:       " <<(fitClocks / CLOCKS_PER_SEC) <<" s" <<endl ;
  cout <<"Data plotting time:     " <<(dataSetClocks / CLOCKS_PER_SEC) <<" s" <<endl ;
  cout <<"PDF sum time:           " <<(sumClocks / CLOCKS_PER_SEC) <<" s" <<endl ;
  cout <<"PDF normalisation time: " <<(normClocks / CLOCKS_PER_SEC) <<" s" <<endl ;
  cout <<"PDF projection time:    " <<(projClocks / CLOCKS_PER_SEC) <<" s" <<endl ;
  cout <<"~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~" <<endl;

  return 0;

}
