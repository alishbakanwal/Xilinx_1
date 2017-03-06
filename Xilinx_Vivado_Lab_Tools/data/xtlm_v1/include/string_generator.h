#include<cstring>
#include "svdpi.h"
using namespace std;
#ifndef _GENERATE_STRING
#define _GENERATE_STRING

union _data{
  unsigned int i;
  char c[4];
}_data1;

class StringGenerator {
public:
  static string svLogicVecValToString(const svLogicVecVal* name)
  {
    const svLogicVecVal* vlogdata_array = name;

    char appendedData[255] = {0x0};//Rest will be automatically initialized to 0
    char _data_name[5];
    _data_name[4] = '\0';
    for(int vlogDataWordItr = (2040/32) ; vlogDataWordItr >= 0; vlogDataWordItr--)
    {
      _data1.i = vlogdata_array[vlogDataWordItr].aval;
      memmove(_data_name,_data1.c,4);
      int name_length = strlen(_data_name);
      if(strlen(_data_name) != 0)
      {
        char local_data[name_length];
        if (name_length > 4)
        {
          name_length = 4;
        }

        for (int bit_itr = (name_length - 1),local_bit_itr = 0; bit_itr >= 0,local_bit_itr < name_length; bit_itr--,local_bit_itr++)
        {
          local_data[local_bit_itr] = _data_name[bit_itr];
        }
        strncat(appendedData,local_data,name_length);
      }
    }
    string returname(appendedData);
    //returname += '\0';
    return returname;
  }
};

#endif


// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
