#include <map>
#include <string>
#include <cstdlib>
#include <cstdint>
using namespace std;
#ifndef MODEL_PARAMS
#define MODEL_PARAMS
class ModelParams_imp;
class ModelParams{
public:
  ModelParams();
  void add_clk_id(string clk_name, string clk_id);
  string get_clk_id(string clk_name);
  string get_clk_name(string clk_id);
  
  void set_int_param(string name, int64_t value);
  void set_str_param(string name, string value);
  
  int64_t get_int_param(string name);
  string get_str_param(string name);	
  ~ModelParams();
protected:
private:
  ModelParams_imp* p_imp;
};
#endif


// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
