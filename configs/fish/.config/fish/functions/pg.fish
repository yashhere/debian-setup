function pg --wraps='ps -ax | grep -i' --description 'alias pg=ps -ax | grep -i'
  command ps -ax | grep -i $argv;
end