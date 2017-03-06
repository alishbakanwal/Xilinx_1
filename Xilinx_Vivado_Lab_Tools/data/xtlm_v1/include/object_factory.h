#include <string>
#include <map>
using namespace std;
#ifndef MODEL_FACTORY
#define MODEL_FACTORY
struct voidptr_cmpare {
  bool operator()(void* a, void* b) {
    return (reinterpret_cast<int*>(a) < reinterpret_cast<int*>(b));
  }
};
template<class t>
class ObjectFactory{
public:
  static ObjectFactory<t>* factory(){
  //static ObjectFactory instance;

    if(instance != NULL)
      return instance;
    return instance = new ObjectFactory();
  }
  t* getNamedInstance(void* context){
    if(objectTrove.find(context) == objectTrove.end()){
      t* t_ptr= new t(context);
      objectTrove[context] = t_ptr;
      return t_ptr;
    }else{
      return objectTrove[context];
    }
  }
  t* getNamedInstance(std::string context){
    if(objectTroveString.find(context) == objectTroveString.end()){
      t* t_ptr= new t(context.c_str());
      objectTroveString[context] = t_ptr;
      return t_ptr;
    }else{
      return objectTroveString[context];
    }
  }
    /*void destroyAll(){
    typename map<void*, t* >::iterator objectIter = objectTrove.begin();
    for(;objectIter != objectTrove.end(); objectIter++){
      delete (*objectIter).second;
    }
  }

  void reset_simulation_model(string ip_name){

    typename map<void*, t* >::iterator objectIter = objectTrove.find(ip_name);
    if(objectIter != objectTrove.end()){
      //delete objectIter->second;
      objectTrove.erase(objectIter);	
    }
  }*/
protected:
private:
map<void*, t*, voidptr_cmpare> objectTrove;
map<string, t*> objectTroveString;
static ObjectFactory* instance;
//ObjectFactory(){}
};
//ObjectFactory* ObjectFactory::instance = NULL;
#endif


// XSIP watermark, do not delete 67d7842dbbe25473c3c32b93c0da8047785f30d78e8a024de1b57352245f9689
